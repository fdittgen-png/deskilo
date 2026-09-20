// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #977 — the instance builder over a fake Management API: the project
// comes up after a few polls, the schema runs in order and names the
// migration that fails, the functions deploy with their JWT rule, the
// endpoint is the project's URL and publishable key.
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_bundle.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/instance_security_checks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_supabase_management.dart';

const _bundleJson = '''
{"schema":[{"name":"0001_a.sql","sql":"create table a(); select public.set_deskilo_schema_version(1);"},
           {"name":"0002_b.sql","sql":"create table b(); select public.set_deskilo_schema_version(2);"},
           {"name":"0003_c.sql","sql":"create table c(); select public.set_deskilo_schema_version(3);"}],
 "functions":[{"slug":"send-push","verifyJwt":true,"files":[{"name":"index.ts","content":"x"}]},
              {"slug":"stripe-webhook","verifyJwt":false,"files":[{"name":"index.ts","content":"y"}]}]}
''';

void main() {
  test('the bundle parses with its version', () {
    final bundle = parseInstanceBundle(_bundleJson);
    expect(bundle.schema.map((m) => m.name), ['0001_a.sql', '0002_b.sql', '0003_c.sql']);
    expect(bundle.schemaVersion, '0003');
    expect(bundle.functions.last.verifyJwt, isFalse);
  });

  test('create → ready after polls; schema in order; functions with their '
      'JWT rule; the endpoint', () async {
    final api = FakeSupabaseManagement()..readyAfterPolls = 2;
    final builder = InstanceBuilder(api);
    final statuses = <String>[];
    final project = await builder.createProject(
      organizationId: 'org-1',
      name: 'Pézenas',
      region: 'eu-west-3',
      databasePassword: 'pw',
      poll: Duration.zero,
      onStatus: statuses.add,
    );
    expect(project.status, 'ACTIVE_HEALTHY');
    expect(statuses, ['COMING_UP', 'COMING_UP', 'ACTIVE_HEALTHY']);

    final bundle = parseInstanceBundle(_bundleJson);
    final progress = <InstanceProgress>[];
    await builder.installSchema(project.ref, bundle, onProgress: progress.add);
    expect(
      [
        for (final sql in api.sql[project.ref]!)
          RegExp(r'create table (\w)\(\)').firstMatch(sql)!.group(1),
      ],
      ['a', 'b', 'c'],
    );
    expect(api.recorded[project.ref], ['0001', '0002', '0003'],
        reason: '#1314 — every migration is recorded as it applies');
    expect(progress.last, (done: 3, total: 3, current: ''));

    await builder.deployFunctions(project.ref, bundle);
    expect(api.deployed[project.ref]!.map((d) => '${d.slug}:${d.verifyJwt}'),
        ['send-push:true', 'stripe-webhook:false']);

    await builder.configureAuth(project.ref);
    expect(api.authPatches[project.ref]!.single['mailer_autoconfirm'], false);

    final endpoint = await builder.endpointOf(project.ref);
    expect(endpoint.url, 'https://${project.ref}.supabase.co');
    expect(endpoint.key, startsWith('sb_publishable_'));
  });

  test('a failing migration is named, with the database\'s words, and a '
      'resume skips what ran', () async {
    final api = FakeSupabaseManagement()
      ..failSqlContaining = 'table b'
      ..failMessage = 'relation "b" already exists';
    final builder = InstanceBuilder(api);
    final bundle = parseInstanceBundle(_bundleJson);
    await expectLater(
      builder.installSchema('ref-1', bundle),
      throwsA(isA<InstanceStepFailure>()
          .having((e) => e.item, 'item', '0002_b.sql')
          .having((e) => e.message, 'message', contains('already exists'))),
    );
    expect(api.sql['ref-1'], hasLength(1));
    expect(api.recorded['ref-1'], ['0001'],
        reason: 'the failed migration left no record behind');
    api.failSqlContaining = null;
    await builder.installSchema('ref-1', bundle, skip: 1);
    expect(api.sql['ref-1'], hasLength(3));
  });

  test('a project that never comes up is a failure, not a hang', () async {
    final api = FakeSupabaseManagement()..readyAfterPolls = 99;
    await expectLater(
      InstanceBuilder(api).waitUntilReady('ref-1', poll: Duration.zero, maxPolls: 3),
      throwsA(isA<InstanceStepFailure>()),
    );
  });

  test('regions and passwords', () {
    expect(defaultRegionFor('FR'), 'eu-west-3');
    expect(defaultRegionFor('DE'), 'eu-central-1');
    expect(defaultRegionFor('XX'), 'eu-west-1');
    expect(supabaseRegions.map((r) => r.code), contains('eu-west-3'));
    final pw = generateDatabasePassword();
    expect(pw, hasLength(24));
    expect(pw, matches(RegExp(r'^[A-Za-z0-9]+$')));
  });

  group('#1314 — an install records, resumes, and never runs a migration '
      'twice', () {
    test('one request carries the migration and its record, in that order',
        () {
      final sql = InstanceBuilder.recordedMigrationSql(
          (name: '0214_booking_idempotency.sql', sql: 'create table x();'));
      final migration = sql.indexOf('create table x();');
      final record = sql.indexOf(
          "values ('0214', '0214_booking_idempotency')");
      expect(migration, greaterThanOrEqualTo(0));
      expect(record, greaterThan(migration),
          reason: 'the record follows the migration inside the same '
              'transaction, so it exists exactly when the migration applied');
      expect(sql, contains('on conflict (version) do nothing'));
      expect(sql, contains('create table if not exists '
          'supabase_migrations.schema_migrations'));
    });

    test('an interrupted install resumes from what the project recorded',
        () async {
      final api = FakeSupabaseManagement()..failSqlContaining = 'table c';
      final builder = InstanceBuilder(api);
      final bundle = parseInstanceBundle(_bundleJson);
      await expectLater(builder.installSchema('ref-1', bundle),
          throwsA(isA<InstanceStepFailure>()));
      expect(api.recorded['ref-1'], ['0001', '0002']);
      expect(await builder.resumePoint('ref-1', bundle), 2);

      api.failSqlContaining = null;
      // No --skip: the project says where it stopped.
      await builder.installSchema('ref-1', bundle);
      for (final table in ['a', 'b', 'c']) {
        expect(
          api.sql['ref-1']!.where((s) => s.contains('create table $table();')),
          hasLength(1),
          reason: 'migration $table ran exactly once',
        );
      }
      expect(await builder.resumePoint('ref-1', bundle), 3);
    });

    test('a project migrated by other tooling is not resumed by guesswork',
        () async {
      final api = FakeSupabaseManagement()..foreignRecorded = 230;
      final builder = InstanceBuilder(api);
      final bundle = parseInstanceBundle(_bundleJson);
      expect(await builder.resumePoint('ref-1', bundle), isNull);
      await expectLater(
        builder.installSchema('ref-1', bundle),
        throwsA(isA<InstanceStepFailure>()
            .having((e) => e.message, 'message', contains('--skip'))),
      );
      expect(api.sql['ref-1'], isNull,
          reason: 're-running migrations on a working schema breaks it');
    });

    test('#1312 — the marker decides where an upgrade starts, whatever was '
        'recorded', () async {
      // A schema some other path applied through 0002 — the CLI, a psql
      // restore — carries its marker and no record this tooling wrote.
      final api = FakeSupabaseManagement()..markers['ref-1'] = 2;
      final builder = InstanceBuilder(api);
      final bundle = parseInstanceBundle(_bundleJson);
      expect(await builder.resumePoint('ref-1', bundle), 2);
      await builder.installSchema('ref-1', bundle);
      expect(api.sql['ref-1'], hasLength(1));
      expect(api.sql['ref-1']!.single, contains('create table c();'),
          reason: 'exactly the missing migration runs, once');
      expect(api.markers['ref-1'], 3);
      expect(await builder.resumePoint('ref-1', bundle), 3,
          reason: 'a second upgrade has nothing left to run');
    });

    test('#1312 — the marker wins over foreign bookkeeping', () async {
      final api = FakeSupabaseManagement()
        ..foreignRecorded = 230
        ..markers['ref-1'] = 1;
      final bundle = parseInstanceBundle(_bundleJson);
      expect(await InstanceBuilder(api).resumePoint('ref-1', bundle), 1);
    });

    test('record marks the migrations a project already has, running none',
        () async {
      final api = FakeSupabaseManagement();
      final builder = InstanceBuilder(api);
      final bundle = parseInstanceBundle(_bundleJson);
      expect(await builder.recordApplied('ref-1', bundle, '0002'), 2);
      expect(api.recorded['ref-1'], ['0001', '0002']);
      expect(api.sql['ref-1']!.single, isNot(contains('create table a')),
          reason: 'only the bookkeeping is written; no migration body runs');
      expect(await builder.resumePoint('ref-1', bundle), 2);
    });

    test('installed, then examined: the doctor calls the schema sound',
        () async {
      // Red before #1314: the install recorded nothing, so the doctor read
      // zero migrations and raised an alarm on every instance it built.
      final api = FakeSupabaseManagement()
        ..authConfigValue = {
          'site_url': InstanceAuthConfig.siteUrl,
          'uri_allow_list': InstanceAuthConfig.redirectAllowList,
          'mailer_autoconfirm': false,
        };
      api.onQuery = (ref, sql) {
        if (sql == InstanceDoctor.schemaHealthSql) {
          return [
            {'marker': api.markers[ref], 'tables': 3},
          ];
        }
        if (sql == InstanceDoctor.securityHealthSql) {
          return [
            {
              'tables_without_rls': '',
              'open_policyless': '',
              'anon_definers': '',
              'buckets': 'avatars, floor-plans',
            },
          ];
        }
        // #1313 — the structural checks run in the same examine.
        if (sql == policyDriftSql) {
          return [
            {'policies': 'public.invoices.invoices_select'},
          ];
        }
        if (sql == storageReadPolicySql) {
          return [
            {
              'read_policies': 'floor_plans_select :: '
                  'is_member_of(((storage.foldername(name))[1])::uuid)',
            },
          ];
        }
        if (sql == guardHealthSql) {
          return [
            {
              'realtime_unprotected': '',
              'definers_unpinned': '',
              'anon_views': '',
              'secret_grants': '',
              'public_buckets': '',
            },
          ];
        }
        return [
          {'created_7d': 0, 'confirmed_7d': 0, 'stuck': 0, 'oldest_stuck_hours': 0},
        ];
      };
      final builder = InstanceBuilder(api);
      final bundle = parseInstanceBundle(_bundleJson);
      await builder.installSchema('ref-1', bundle);

      final findings = await InstanceDoctor(api).examine(
        'ref-1',
        required: int.parse(bundle.schemaVersion),
        bundleMigrations: [for (final m in bundle.schema) m.name],
        expectedPolicies: const {'public.invoices.invoices_select'},
      );
      expect(findings.where((f) => f.isProblem), isEmpty,
          reason: findings.join('\n'));
      expect(findings.firstWhere((f) => f.title == 'Schema').detail,
          contains('version 3, current'));
    });
  });
}
