// SPDX-License-Identifier: 0BSD
//
// #1308 S1 — nothing is installed onto an existing project without a
// verdict on what it already holds.
//
// Read-only: one `query` for the facts, plus the resume point #1314 already
// reads. The wizard shows the verdict and runs nothing when the answer is
// "needs attention".
import 'instance_builder.dart';
import 'instance_bundle.dart';
import 'management_api.dart';

enum InstanceReadinessVerdict {
  /// Nothing in `public`: the full install runs.
  install,

  /// This tooling recorded part of the bundle and no marker yet: the
  /// install resumes after the last recorded migration.
  resume,

  /// A DesKilo schema with a version marker older than this bundle: only
  /// the missing migrations run — never a reinstall.
  upgrade,

  /// A DesKilo schema at exactly this bundle's version: nothing to install.
  current,

  /// Something here must be decided by a person first; nothing runs.
  needsAttention,
}

/// Why a project needs attention.
enum InstanceAttention {
  /// The project is not `ACTIVE_HEALTHY`.
  notHealthy,

  /// Postgres major is not the one the schema is written for.
  postgresVersion,

  /// `public` holds tables DesKilo never creates.
  foreignTables,

  /// DesKilo's tables are there, but nothing recorded which migrations ran
  /// (an instance built before #1314): `instance.dart record` first.
  unrecorded,

  /// Migrations were recorded by other tooling (timestamp versions), so
  /// where the bundle resumes cannot be read.
  otherTooling,
}

class InstanceReadiness {
  const InstanceReadiness(
    this.verdict, {
    this.attention,
    this.marker,
    this.postgresMajor,
    this.foreignTables = const [],
    this.pending = 0,
  });

  final InstanceReadinessVerdict verdict;
  final InstanceAttention? attention;

  /// `deskilo_schema_version()`, null before 0226 or on a foreign schema.
  final int? marker;
  final int? postgresMajor;

  /// Up to [InstanceReadinessCheck.namedTables] foreign table names.
  final List<String> foreignTables;

  /// Bundle migrations still to run.
  final int pending;

  bool get blocks => verdict == InstanceReadinessVerdict.needsAttention;
}

/// The Postgres major the migrations are written and tested for.
const int supportedPostgresMajor = 17;

/// Tables the bundle's migrations create, lower case, without schema.
Set<String> bundleTables(InstanceBundle bundle) => {
      for (final m in bundle.schema)
        for (final match in RegExp(
          r'create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?"?([a-z_][a-z0-9_]*)"?',
          caseSensitive: false,
        ).allMatches(m.sql))
          match.group(1)!.toLowerCase(),
    };

class InstanceReadinessCheck {
  const InstanceReadinessCheck(this.api);

  final SupabaseManagement api;

  static const int namedTables = 5;

  /// The server's version and the tables in `public` that no extension
  /// owns. Read-only.
  static const String factsSql = r'''
select current_setting('server_version_num')::int as server_version_num,
  (select string_agg(c.relname, ',' order by c.relname)
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and not exists (select 1 from pg_depend d
                       where d.classid = 'pg_class'::regclass
                         and d.objid = c.oid and d.deptype = 'e')) as public_tables;
''';

  Future<InstanceReadiness> examine(
      SupabaseProject project, InstanceBundle bundle) async {
    if (project.status != 'ACTIVE_HEALTHY') {
      return const InstanceReadiness(InstanceReadinessVerdict.needsAttention,
          attention: InstanceAttention.notHealthy);
    }
    final rows = await api.query(project.ref, factsSql);
    final facts = rows.isEmpty ? const <String, Object?>{} : rows.first;
    final versionNum = int.tryParse('${facts['server_version_num'] ?? ''}');
    final major = versionNum == null ? null : versionNum ~/ 10000;
    if (major != null && major != supportedPostgresMajor) {
      return InstanceReadiness(InstanceReadinessVerdict.needsAttention,
          attention: InstanceAttention.postgresVersion, postgresMajor: major);
    }
    final publicTables = '${facts['public_tables'] ?? ''}'
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet();

    final builder = InstanceBuilder(api);
    final resume = await builder.resumePoint(project.ref, bundle);
    final marker = await _marker(project.ref);
    if (resume == null) {
      return InstanceReadiness(InstanceReadinessVerdict.needsAttention,
          attention: InstanceAttention.otherTooling,
          marker: marker,
          postgresMajor: major);
    }
    final pending = bundle.schema.length - resume;
    if (marker != null) {
      return InstanceReadiness(
          pending == 0
              ? InstanceReadinessVerdict.current
              : InstanceReadinessVerdict.upgrade,
          marker: marker,
          postgresMajor: major,
          pending: pending);
    }
    final ours = bundleTables(bundle);
    final foreign = (publicTables.difference(ours).toList()..sort());
    if (foreign.isNotEmpty) {
      return InstanceReadiness(InstanceReadinessVerdict.needsAttention,
          attention: InstanceAttention.foreignTables,
          postgresMajor: major,
          foreignTables: foreign.take(namedTables).toList());
    }
    if (resume > 0) {
      return InstanceReadiness(InstanceReadinessVerdict.resume,
          postgresMajor: major, pending: pending);
    }
    if (publicTables.isNotEmpty) {
      return InstanceReadiness(InstanceReadinessVerdict.needsAttention,
          attention: InstanceAttention.unrecorded, postgresMajor: major);
    }
    return InstanceReadiness(InstanceReadinessVerdict.install,
        postgresMajor: major, pending: pending);
  }

  Future<int?> _marker(String ref) async {
    final rows = await api.query(ref, InstanceBuilder.recordedVersionsSql);
    return rows.isEmpty ? null : int.tryParse('${rows.first['marker'] ?? ''}');
  }
}
