// SPDX-License-Identifier: 0BSD
//
// #1308 S1 — an existing project gets a verdict before anything is
// installed onto it, and reading it runs no SQL that writes.
import 'package:deskilo/core/instance/instance_bundle.dart';
import 'package:deskilo/core/instance/instance_readiness.dart';
import 'package:deskilo/core/instance/management_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_supabase_management.dart';

const _bundle = InstanceBundle(schema: [
  (name: '0001_a.sql', sql: 'create table public.alpha (id int);'),
  (name: '0002_b.sql', sql: 'create table if not exists beta (id int);'),
], functions: []);

SupabaseProject _project({String status = 'ACTIVE_HEALTHY'}) => (
      ref: 'p1',
      name: 'Existing',
      organizationId: 'org-1',
      region: 'eu-west-3',
      status: status,
    );

FakeSupabaseManagement _api({int version = 170006, String? tables}) =>
    FakeSupabaseManagement()
      ..onQuery = (ref, sql) => sql == InstanceReadinessCheck.factsSql
          ? [
              {'server_version_num': version, 'public_tables': tables},
            ]
          : const [];

Future<InstanceReadiness> _examine(FakeSupabaseManagement api,
        {String status = 'ACTIVE_HEALTHY'}) =>
    InstanceReadinessCheck(api).examine(_project(status: status), _bundle);

void main() {
  test('the tables a bundle creates are read from its migrations', () {
    expect(bundleTables(_bundle), {'alpha', 'beta'});
  });

  test('an empty project installs everything', () async {
    final api = _api();
    final r = await _examine(api);
    expect(r.verdict, InstanceReadinessVerdict.install);
    expect(r.pending, 2);
    expect(api.sql, isEmpty, reason: 'the check writes nothing');
  });

  test('a foreign table in public needs attention and nothing runs',
      () async {
    final api = _api(tables: 'orders,alpha');
    final r = await _examine(api);
    expect(r.verdict, InstanceReadinessVerdict.needsAttention);
    expect(r.attention, InstanceAttention.foreignTables);
    expect(r.foreignTables, ['orders']);
    expect(r.blocks, isTrue);
    expect(api.sql, isEmpty);
  });

  test('a DesKilo marker offers the upgrade, never a reinstall', () async {
    final api = _api(tables: 'alpha')..markers['p1'] = 1;
    final r = await _examine(api);
    expect(r.verdict, InstanceReadinessVerdict.upgrade);
    expect(r.marker, 1);
    expect(r.pending, 1, reason: 'only the migration after the marker');
  });

  test('a marker at the bundle version is current', () async {
    final api = _api(tables: 'alpha,beta')..markers['p1'] = 2;
    expect((await _examine(api)).verdict, InstanceReadinessVerdict.current);
  });

  test('a recorded partial install resumes', () async {
    final api = _api(tables: 'alpha')..recorded['p1'] = ['0001'];
    final r = await _examine(api);
    expect(r.verdict, InstanceReadinessVerdict.resume);
    expect(r.pending, 1);
  });

  test('DesKilo tables with nothing recorded ask for `record` first',
      () async {
    final r = await _examine(_api(tables: 'alpha'));
    expect(r.attention, InstanceAttention.unrecorded);
  });

  test('migrations recorded by other tooling need attention', () async {
    final api = _api()..foreignRecorded = 3;
    expect((await _examine(api)).attention, InstanceAttention.otherTooling);
  });

  test('another Postgres major needs attention', () async {
    final r = await _examine(_api(version: 150008));
    expect(r.attention, InstanceAttention.postgresVersion);
    expect(r.postgresMajor, 15);
  });

  test('a project that is not healthy is not even queried', () async {
    final api = _api();
    final r = await _examine(api, status: 'PAUSED');
    expect(r.attention, InstanceAttention.notHealthy);
    expect(api.queriedSql, isEmpty);
  });
}
