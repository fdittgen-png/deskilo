// SPDX-License-Identifier: 0BSD
//
// #977 — the instance builder over a fake Management API: the project
// comes up after a few polls, the schema runs in order and names the
// migration that fails, the functions deploy with their JWT rule, the
// endpoint is the project's URL and publishable key.
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_supabase_management.dart';

const _bundleJson = '''
{"schema":[{"name":"0001_a.sql","sql":"create table a();"},
           {"name":"0002_b.sql","sql":"create table b();"},
           {"name":"0003_c.sql","sql":"create table c();"}],
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
    expect(api.sql[project.ref], ['create table a();', 'create table b();', 'create table c();']);
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
    expect(api.sql['ref-1'], ['create table a();']);
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
}
