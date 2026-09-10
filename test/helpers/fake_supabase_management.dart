// SPDX-License-Identifier: 0BSD
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
    queriedSql.add(sql);
    return queryRows;
  }

  @override
  Future<Map<String, Object?>> authConfig(String ref) async => authConfigValue;

  @override
  Future<void> patchAuthConfig(String ref, Map<String, Object?> config) async {
    (authPatches[ref] ??= []).add(config);
  }
}
