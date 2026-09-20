// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/management_api.dart';

/// An in-memory Management API (#977): records every call, brings a
/// project up after [readyAfterPolls] status reads, and can fail one
/// migration on demand.
class FakeSupabaseManagement implements SupabaseManagement {
  final organizations = <SupabaseOrganization>[(id: 'org-1', name: 'Coworkonti')];
  final projects = <SupabaseProject>[];
  final sql = <String, List<String>>{};
  final deployed = <String, List<({String slug, bool verifyJwt})>>{};
  final authPatches = <String, List<Map<String, Object?>>>{};
  final polls = <String, int>{};
  int readyAfterPolls = 0;
  String? failSqlContaining;
  String failMessage = 'syntax error';
  bool unauthorized = false;

  /// #1314 — the versions each project recorded, read out of the recording
  /// insert the installer sends with every migration.
  final recorded = <String, List<String>>{};

  /// #1312 — each project's schema version marker, as the migrations the
  /// installer ran wrote it (`set_deskilo_schema_version(N)`), or as a test
  /// seeds it for a schema some other path applied.
  final markers = <String, int>{};

  /// Rows recorded by OTHER tooling (timestamp versions), per project.
  int foreignRecorded = 0;
  String? failQueryContaining;
  List<Map<String, Object?>> Function(String ref, String sql)? onQuery;

  void _auth() {
    if (unauthorized) throw const ManagementApiException(401, 'Unauthorized');
  }

  @override
  Future<List<SupabaseOrganization>> listOrganizations() async {
    _auth();
    return organizations;
  }

  @override
  Future<List<SupabaseProject>> listProjects() async {
    _auth();
    return projects;
  }

  @override
  Future<SupabaseProject> createProject({
    required String organizationId,
    required String name,
    required String region,
    required String databasePassword,
  }) async {
    _auth();
    final p = (
      ref: 'ref${projects.length + 1}',
      name: name,
      organizationId: organizationId,
      region: region,
      status: 'COMING_UP',
    );
    projects.add(p);
    return p;
  }

  @override
  Future<SupabaseProject> project(String ref) async {
    _auth();
    final n = (polls[ref] ?? 0) + 1;
    polls[ref] = n;
    final base = projects.where((p) => p.ref == ref).firstOrNull ??
        (ref: ref, name: ref, organizationId: 'org-1', region: 'eu-west-3', status: 'COMING_UP');
    return (
      ref: base.ref,
      name: base.name,
      organizationId: base.organizationId,
      region: base.region,
      status: n > readyAfterPolls ? 'ACTIVE_HEALTHY' : 'COMING_UP',
    );
  }

  @override
  Future<void> runSql(String ref, String sql) async {
    _auth();
    final needle = failSqlContaining;
    if (needle != null && sql.contains(needle)) {
      throw ManagementApiException(400, failMessage);
    }
    (this.sql[ref] ??= []).add(sql);
    for (final m in RegExp(r'set_deskilo_schema_version\((\d+)\)').allMatches(sql)) {
      final v = int.parse(m.group(1)!);
      if (v > (markers[ref] ?? 0)) markers[ref] = v;
    }
    if (sql.contains('insert into supabase_migrations.schema_migrations')) {
      for (final m in RegExp(r"\('(\d{4})', '").allMatches(sql)) {
        final version = m.group(1)!;
        final list = recorded[ref] ??= [];
        if (!list.contains(version)) list.add(version);
      }
    }
  }

  /// #1308 — functions a project carried before this fake deployed any.
  final existingFunctions = <String, List<String>>{};

  @override
  Future<List<String>> listFunctions(String ref) async {
    _auth();
    return {
      ...?existingFunctions[ref],
      for (final d in deployed[ref] ?? const <({String slug, bool verifyJwt})>[])
        d.slug,
    }.toList();
  }

  @override
  Future<void> deployFunction(String ref,
      {required String slug,
      required bool verifyJwt,
      required List<({String name, String content})> files}) async {
    _auth();
    (deployed[ref] ??= []).add((slug: slug, verifyJwt: verifyJwt));
  }

  @override
  Future<String> publishableKey(String ref) async => 'sb_publishable_${ref}_key';

  /// What `query` hands back; the doctor's tests drive the pure
  /// functions directly, so this only has to exist and be settable.
  List<Map<String, Object?>> queryRows = const [];
  Map<String, Object?> authConfigValue = const {};
  final queriedSql = <String>[];

  @override
  Future<List<Map<String, Object?>>> query(String ref, String sql) async {
    _auth();
    queriedSql.add(sql);
    final needle = failQueryContaining;
    if (needle != null && sql.contains(needle)) {
      throw ManagementApiException(400, failMessage);
    }
    if (sql == InstanceBuilder.recordedVersionsSql) {
      final versions = recorded[ref] ?? const <String>[];
      return [
        {
          'present': versions.isNotEmpty || foreignRecorded > 0,
          'recorded': versions.length + foreignRecorded,
          'versions': versions.isEmpty ? null : versions.join(','),
          'marker': markers[ref],
        },
      ];
    }
    return onQuery?.call(ref, sql) ?? queryRows;
  }

  /// #1308 — per-project live auth config; falls back to [authConfigValue].
  final authConfigs = <String, Map<String, Object?>>{};

  @override
  Future<Map<String, Object?>> authConfig(String ref) async =>
      authConfigs[ref] ?? authConfigValue;

  @override
  Future<void> patchAuthConfig(String ref, Map<String, Object?> config) async {
    (authPatches[ref] ??= []).add(config);
  }
}
