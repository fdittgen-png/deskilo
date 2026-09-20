// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1337 — the database half of the Supabase Management API, answered by
// `psql` against a real Postgres, so the REAL InstanceBuilder,
// InstanceReadinessCheck and InstanceDoctor can be run end to end in CI.
//
// There is no Management API for a local stack. Everything the lifecycle
// decides, though, it decides from SQL: which migrations ran, where an
// install resumes, whether a project is empty, what the doctor finds. That
// half is real here, with the same transaction semantics:
//
//   * `runSql` sends the whole string as ONE `psql -c` query. Postgres runs
//     a multi-statement simple query as a single implicit transaction, as
//     the Management API does: a failing statement rolls back everything
//     before it, the migration and its record together.
//   * `query` wraps the statement in `json_agg`, so rows come back typed
//     the way the API's JSON answer types them.
//   * A database error becomes a `ManagementApiException` with status 400,
//     which is what the API answers and what the doctor's probe isolation
//     catches.
//
// NOT covered, and documented as such: `project` answers ACTIVE_HEALTHY
// (or the status a scenario sets), `listFunctions` answers the slugs it
// was given, `authConfig` answers InstanceAuthConfig, and `deployFunction`
// and `patchAuthConfig` only count their calls. A function deploy and the
// auth settings exist only on a hosted project.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/management_api.dart';

/// Runs `psql` with [args] and returns its result. The seam the unit tests
/// replace.
typedef PsqlRunner =
    Future<ProcessResult> Function(String executable, List<String> args);

Future<ProcessResult> _runProcess(String executable, List<String> args) =>
    Process.run(executable, args, stdoutEncoding: utf8, stderrEncoding: utf8);

/// A single argument larger than this is refused by `execve` on Linux
/// (MAX_ARG_STRLEN is 128 KiB). Said plainly instead of failing obscurely.
const int maxSqlBytes = 120000;

/// [sql] as one select that answers its rows as a JSON array.
String jsonRowsSql(String sql) {
  var body = sql.trimRight();
  while (body.endsWith(';')) {
    body = body.substring(0, body.length - 1).trimRight();
  }
  return "select coalesce(json_agg(q), '[]'::json) from (\n$body\n) q";
}

/// The rows of a [jsonRowsSql] answer, as `-At` prints it.
List<Map<String, Object?>> parseJsonRows(String stdout) {
  final text = stdout.trim();
  if (text.isEmpty) return const [];
  final decoded = jsonDecode(text);
  if (decoded is! List) {
    throw FormatException('expected a JSON array of rows', text);
  }
  return [
    for (final row in decoded.cast<Map<dynamic, dynamic>>())
      {for (final e in row.entries) '${e.key}': e.value as Object?},
  ];
}

/// The database's own words from `psql`'s stderr: the ERROR line and its
/// DETAIL/HINT, without the `psql:` prefix. Falls back to all of stderr.
String psqlErrorMessage(String stderr) {
  final lines = const LineSplitter().convert(stderr);
  final start = lines.indexWhere((l) => l.contains('ERROR:'));
  if (start < 0) {
    final all = stderr.trim();
    return all.isEmpty ? 'psql failed without a message' : all;
  }
  final error = lines[start];
  final message = error.substring(error.indexOf('ERROR:') + 6).trim();
  final more = [
    for (final l in lines.skip(start + 1))
      if (l.startsWith('DETAIL:') || l.startsWith('HINT:')) l.trim(),
  ];
  return [message, ...more].join('\n');
}

/// The migration version a [InstanceBuilder.recordedMigrationSql] string
/// records, or null for any other SQL.
String? recordedVersionOf(String sql) {
  final matches = RegExp(
    r"insert into supabase_migrations\.schema_migrations \(version, name\)\s*"
    r"values \('(\d{4})'",
  ).allMatches(sql);
  return matches.isEmpty ? null : matches.last.group(1);
}

class PsqlSupabaseManagement implements SupabaseManagement {
  PsqlSupabaseManagement({
    required this.psql,
    this.functionSlugs = const [],
    this.status = 'ACTIVE_HEALTHY',
    PsqlRunner? runner,
  }) : assert(psql.isNotEmpty),
       _run = runner ?? _runProcess;

  /// The command that starts `psql`, e.g.
  /// `docker exec supabase_db_deskilo psql -U postgres`. The project ref is the database name, passed as `-d`.
  final List<String> psql;

  /// What [listFunctions] answers.
  final List<String> functionSlugs;

  /// What [project] answers as the project's status.
  String status;

  final PsqlRunner _run;

  /// Every SQL string [runSql] sent, in order — whether it succeeded or not.
  final List<String> mutations = [];

  /// Every SQL string [query] sent, in order.
  final List<String> queries = [];

  /// Function deploys and auth patches asked for; nothing is deployed.
  final List<String> notCovered = [];

  /// Called after each [runSql] that succeeded — a scenario reads the
  /// database between two migrations here.
  Future<void> Function(String ref, String sql)? afterRunSql;

  Future<String> _psql(String ref, List<String> flags, String sql) async {
    if (utf8.encode(sql).length > maxSqlBytes) {
      throw const ManagementApiException(
        413,
        'the SQL is larger than one psql argument may be ($maxSqlBytes bytes)',
      );
    }
    final result = await _run(psql.first, [
      ...psql.skip(1),
      '-X',
      '-q',
      '-d',
      ref,
      ...flags,
      '-c',
      sql,
    ]);
    if (result.exitCode != 0) {
      final stderr = '${result.stderr}';
      throw ManagementApiException(
        stderr.contains('ERROR:') ? 400 : 500,
        psqlErrorMessage(stderr),
      );
    }
    return '${result.stdout}';
  }

  @override
  Future<void> runSql(String ref, String sql) async {
    mutations.add(sql);
    await _psql(ref, const ['-v', 'ON_ERROR_STOP=1'], sql);
    await afterRunSql?.call(ref, sql);
  }

  @override
  Future<List<Map<String, Object?>>> query(String ref, String sql) async {
    queries.add(sql);
    final out = await _psql(ref, const [
      '-v',
      'ON_ERROR_STOP=1',
      '-A',
      '-t',
    ], jsonRowsSql(sql));
    return parseJsonRows(out);
  }

  @override
  Future<SupabaseProject> project(String ref) async => (
    ref: ref,
    name: ref,
    organizationId: 'local',
    region: 'local',
    status: status,
  );

  @override
  Future<List<SupabaseOrganization>> listOrganizations() async => const [];

  @override
  Future<List<SupabaseProject>> listProjects() async => const [];

  @override
  Future<SupabaseProject> createProject({
    required String organizationId,
    required String name,
    required String region,
    required String databasePassword,
  }) => throw UnsupportedError('a local database is created by the script');

  @override
  Future<Map<String, Object?>> authConfig(String ref) async =>
      Map.of(InstanceAuthConfig.patch);

  @override
  Future<List<String>> listFunctions(String ref) async =>
      List.of(functionSlugs);

  @override
  Future<void> deployFunction(
    String ref, {
    required String slug,
    required bool verifyJwt,
    required List<({String name, String content})> files,
  }) async => notCovered.add('deploy $slug');

  @override
  Future<String> publishableKey(String ref) async => 'sb_publishable_local';

  @override
  Future<void> patchAuthConfig(String ref, Map<String, Object?> config) async =>
      notCovered.add('auth');
}
