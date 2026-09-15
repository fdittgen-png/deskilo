// SPDX-License-Identifier: 0BSD
import 'dart:math';

import 'instance_bundle.dart';
import 'management_api.dart';

/// The regions a project can live in, with the label a person reads.
/// The nearest one is pre-selected from the workspace's country.
const List<({String code, String label})> supabaseRegions = [
  (code: 'eu-west-3', label: 'Paris (eu-west-3)'),
  (code: 'eu-central-1', label: 'Frankfurt (eu-central-1)'),
  (code: 'eu-central-2', label: 'Zurich (eu-central-2)'),
  (code: 'eu-west-1', label: 'Ireland (eu-west-1)'),
  (code: 'eu-west-2', label: 'London (eu-west-2)'),
  (code: 'eu-north-1', label: 'Stockholm (eu-north-1)'),
  (code: 'us-east-1', label: 'Virginia (us-east-1)'),
  (code: 'us-west-1', label: 'California (us-west-1)'),
  (code: 'ca-central-1', label: 'Canada (ca-central-1)'),
  (code: 'ap-southeast-1', label: 'Singapore (ap-southeast-1)'),
  (code: 'ap-northeast-1', label: 'Tokyo (ap-northeast-1)'),
  (code: 'ap-southeast-2', label: 'Sydney (ap-southeast-2)'),
  (code: 'sa-east-1', label: 'São Paulo (sa-east-1)'),
];

String defaultRegionFor(String countryCode) => switch (countryCode.toUpperCase()) {
      'FR' || 'BE' || 'LU' || 'ES' || 'PT' => 'eu-west-3',
      'DE' || 'AT' || 'NL' || 'PL' || 'CZ' || 'DK' || 'IT' => 'eu-central-1',
      'CH' => 'eu-central-2',
      'GB' || 'IE' => 'eu-west-2',
      'SE' || 'NO' || 'FI' => 'eu-north-1',
      'US' => 'us-east-1',
      'CA' => 'ca-central-1',
      'AU' || 'NZ' => 'ap-southeast-2',
      'JP' => 'ap-northeast-1',
      'BR' => 'sa-east-1',
      _ => 'eu-west-1',
    };

/// A database password the person never has to invent: letters and
/// digits only, so nothing needs quoting anywhere.
String generateDatabasePassword([Random? random]) {
  const alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  final r = random ?? Random.secure();
  return String.fromCharCodes(
      List.generate(24, (_) => alphabet.codeUnitAt(r.nextInt(alphabet.length))));
}

/// Where the app lives on the web and what its sign-in links look like:
/// what the new instance's auth must allow.
abstract final class InstanceAuthConfig {
  static const String siteUrl = 'https://fdittgen-png.github.io/deskilo/';
  static const String redirectAllowList =
      'deskilo://**,https://fdittgen-png.github.io/deskilo/**';

  static Map<String, Object?> get patch => {
        'mailer_autoconfirm': false,
        'site_url': siteUrl,
        'uri_allow_list': redirectAllowList,
      };
}

/// A step's progress: how many of [total] are done and the name of the
/// current item.
typedef InstanceProgress = ({int done, int total, String current});

/// Where the schema install stopped, for the screen: the migration and
/// the database's own words.
class InstanceStepFailure implements Exception {
  const InstanceStepFailure(this.item, this.message);
  final String item;
  final String message;
  @override
  String toString() => 'InstanceStepFailure($item): $message';
}

/// The steps that build a new instance (#977), each one retryable on
/// its own. Pure orchestration over [SupabaseManagement]; the screen and
/// the CLI both drive it.
class InstanceBuilder {
  const InstanceBuilder(this.api);

  final SupabaseManagement api;

  /// Creates the project and waits until it answers. [poll] is the wait
  /// between two status reads; tests pass zero.
  Future<SupabaseProject> createProject({
    required String organizationId,
    required String name,
    required String region,
    required String databasePassword,
    Duration poll = const Duration(seconds: 5),
    int maxPolls = 120,
    void Function(String status)? onStatus,
  }) async {
    final created = await api.createProject(
      organizationId: organizationId,
      name: name,
      region: region,
      databasePassword: databasePassword,
    );
    return waitUntilReady(created.ref,
        poll: poll, maxPolls: maxPolls, onStatus: onStatus);
  }

  Future<SupabaseProject> waitUntilReady(
    String ref, {
    Duration poll = const Duration(seconds: 5),
    int maxPolls = 120,
    void Function(String status)? onStatus,
  }) async {
    for (var i = 0; i < maxPolls; i++) {
      final p = await api.project(ref);
      onStatus?.call(p.status);
      if (p.status == 'ACTIVE_HEALTHY') return p;
      if (p.status.contains('FAIL') || p.status == 'INACTIVE') {
        throw InstanceStepFailure(ref, p.status);
      }
      if (poll > Duration.zero) await Future<void>.delayed(poll);
    }
    throw InstanceStepFailure(ref, 'still not ready');
  }

  /// #1314 — where Supabase's own tooling records migrations, created in
  /// the same shape when a fresh project does not have it yet.
  static const String _migrationsTableSql = '''
create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations (
  version text primary key,
  statements text[],
  name text,
  created_by text,
  idempotency_key text unique,
  rollback text[]
);
''';

  static String _nameOf(InstanceMigration m) =>
      m.name.endsWith('.sql') ? m.name.substring(0, m.name.length - 4) : m.name;

  static String _versionOf(InstanceMigration m) => m.name.split('_').first;

  static String _quote(String s) => "'${s.replaceAll("'", "''")}'";

  /// #1314 — ONE migration and its record, in one request.
  ///
  /// The Management API runs a request as a single transaction: a failing
  /// statement rolls back everything before it. So a migration is
  /// recorded exactly when it applied, never one without the other — the
  /// file number as `version`, the file name as `name`. Before this the
  /// install recorded nothing, and the doctor called every instance it
  /// built broken.
  static String recordedMigrationSql(InstanceMigration migration) => '''
$_migrationsTableSql${migration.sql.trimRight()}
;
insert into supabase_migrations.schema_migrations (version, name)
values (${_quote(_versionOf(migration))}, ${_quote(_nameOf(migration))})
on conflict (version) do nothing;
''';

  /// What this tooling recorded on a project. Never raises where
  /// `supabase_migrations` does not exist: the table is only read through
  /// `query_to_xml` once `to_regclass` has found it.
  static const String recordedVersionsSql = r'''
select
  to_regclass('supabase_migrations.schema_migrations') is not null as present,
  case when to_regclass('supabase_migrations.schema_migrations') is not null
    then (xpath('/row/c/text()', query_to_xml(
      'select count(*) as c from supabase_migrations.schema_migrations',
      false, true, '')))[1]::text::int
  end as recorded,
  case when to_regclass('supabase_migrations.schema_migrations') is not null
    then (xpath('/row/v/text()', query_to_xml(
      'select string_agg(version, '','' order by version) as v
         from supabase_migrations.schema_migrations
        where version ~ ''^[0-9]{4}$''
      ',
      false, true, '')))[1]::text
  end as versions;
''';

  /// #1314 — where an install resumes: the first bundle migration this
  /// tooling has not recorded on [ref].
  ///
  /// `null` when the project's migrations were recorded by OTHER tooling
  /// (Supabase's CLI writes timestamp versions): nothing there says how
  /// much of the bundle is applied, and re-running a migration on a
  /// schema that has it is how an install breaks a working project.
  Future<int?> resumePoint(String ref, InstanceBundle bundle) async {
    final rows = await api.query(ref, recordedVersionsSql);
    final row = rows.isEmpty ? const <String, Object?>{} : rows.first;
    final recorded = int.tryParse('${row['recorded'] ?? 0}') ?? 0;
    final versions = '${row['versions'] ?? ''}'
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet();
    if (recorded > 0 && versions.isEmpty) return null;
    var next = 0;
    while (next < bundle.schema.length &&
        versions.contains(_versionOf(bundle.schema[next]))) {
      next++;
    }
    return next;
  }

  /// Runs every migration in order, each recorded with it, stopping at the
  /// first failure with the migration named.
  ///
  /// [skip] says where to start. Without it the install resumes from what
  /// the project recorded (#1314) — a closed browser or a lost response
  /// costs nothing — and refuses to guess on a project other tooling
  /// migrated.
  Future<void> installSchema(
    String ref,
    InstanceBundle bundle, {
    int? skip,
    void Function(InstanceProgress progress)? onProgress,
  }) async {
    final total = bundle.schema.length;
    final start = skip ?? await resumePoint(ref, bundle);
    if (start == null) {
      throw const InstanceStepFailure(
        'schema',
        'this project records its migrations with other tooling, so where '
            'the bundle resumes cannot be read from it — pass --skip with the '
            'number of bundle migrations it already has',
      );
    }
    for (var i = start; i < total; i++) {
      final migration = bundle.schema[i];
      onProgress?.call((done: i, total: total, current: migration.name));
      try {
        await api.runSql(ref, recordedMigrationSql(migration));
      } on ManagementApiException catch (e, st) {
        // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
        Error.throwWithStackTrace(InstanceStepFailure(migration.name, e.message), st);
      }
    }
    onProgress?.call((done: total, total: total, current: ''));
  }

  /// #1314 — records bundle migrations up to [throughVersion] as applied
  /// WITHOUT running them.
  ///
  /// For an instance installed before installs recorded anything: its
  /// schema is there and its bookkeeping is not. Returns how many were
  /// recorded; one already recorded is left as it is.
  Future<int> recordApplied(
    String ref,
    InstanceBundle bundle,
    String throughVersion,
  ) async {
    final chosen = [
      for (final m in bundle.schema)
        if (_versionOf(m).compareTo(throughVersion) <= 0) m,
    ];
    if (chosen.isEmpty) return 0;
    final values = [
      for (final m in chosen) '(${_quote(_versionOf(m))}, ${_quote(_nameOf(m))})',
    ].join(',\n  ');
    try {
      await api.runSql(ref, '''
${_migrationsTableSql}insert into supabase_migrations.schema_migrations (version, name)
values
  $values
on conflict (version) do nothing;
''');
    } on ManagementApiException catch (e, st) {
      // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
      Error.throwWithStackTrace(InstanceStepFailure('record', e.message), st);
    }
    return chosen.length;
  }

  Future<void> deployFunctions(
    String ref,
    InstanceBundle bundle, {
    void Function(InstanceProgress progress)? onProgress,
  }) async {
    final total = bundle.functions.length;
    for (var i = 0; i < total; i++) {
      final f = bundle.functions[i];
      onProgress?.call((done: i, total: total, current: f.slug));
      try {
        await api.deployFunction(ref,
            slug: f.slug, verifyJwt: f.verifyJwt, files: f.files);
      } on ManagementApiException catch (e, st) {
        // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
        Error.throwWithStackTrace(InstanceStepFailure(f.slug, e.message), st);
      }
    }
    onProgress?.call((done: total, total: total, current: ''));
  }

  Future<void> configureAuth(String ref) async {
    try {
      await api.patchAuthConfig(ref, InstanceAuthConfig.patch);
    } on ManagementApiException catch (e, st) {
      // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
      Error.throwWithStackTrace(InstanceStepFailure('auth', e.message), st);
    }
  }

  /// The endpoint the devices will use.
  Future<({String url, String key})> endpointOf(String ref) async =>
      (url: 'https://$ref.supabase.co', key: await api.publishableKey(ref));
}
