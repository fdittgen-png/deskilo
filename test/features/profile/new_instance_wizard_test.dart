// SPDX-License-Identifier: 0BSD
//
// #977 — the instance wizard over a fake Management API: token → the
// organisation, the project comes up, the schema and the functions run
// with progress, the sign-in settings apply, and "use here" points the
// device at the new server.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/instance/instance_bundle.dart';
import 'package:deskilo/core/instance/instance_bundle_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_supabase_management.dart';
import '../../helpers/mock_providers.dart';

const _bundleJson = '''
{"schema":[{"name":"0001_a.sql","sql":"create table a();"},{"name":"0002_b.sql","sql":"create table b();"}],
 "functions":[{"slug":"send-push","verifyJwt":true,"files":[{"name":"index.ts","content":"x"}]}]}
''';

Future<({FakeSupabaseManagement api, InMemoryBackendSettingsStore store})> _pump(
    WidgetTester tester) async {
  final api = FakeSupabaseManagement()..readyAfterPolls = 1;
  final store = InMemoryBackendSettingsStore();
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(backendSettings: store),
        supabaseManagementFactoryProvider.overrideWithValue((_) => api),
        instanceBundleLoaderProvider
            .overrideWithValue(() async => parseInstanceBundle(_bundleJson)),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  final tile = find.byKey(const ValueKey('backend-server-tile'));
  await tester.scrollUntilVisible(tile, 250, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
  return (api: api, store: store);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the whole road: token, project, schema, functions, sign-in, '
      'use here', (tester) async {
    final (:api, :store) = await _pump(tester);
    await _tap(tester, 'backend-new-instance');
    expect(find.text('Create a new instance'), findsWidgets);

    await tester.enterText(find.byKey(const ValueKey('instance-token')), 'sbp_token');
    await _tap(tester, 'instance-check-token');
    expect(find.text('Coworkonti'), findsOneWidget, reason: 'the organisation');
    await _tap(tester, 'wizard-next');

    await tester.enterText(find.byKey(const ValueKey('instance-project-name')), 'Pézenas');
    await tester.pumpAndSettle();
    await _tap(tester, 'instance-create-project');
    expect(api.projects.single.name, 'Pézenas');
    expect(find.textContaining('Project ready: ref1'), findsOneWidget);
    await _tap(tester, 'wizard-next');

    await _tap(tester, 'instance-install-schema');
    expect(api.recorded['ref1'], ['0001', '0002'],
        reason: '#1314 — each migration is recorded as it installs');
    await _tap(tester, 'wizard-next');

    await _tap(tester, 'instance-deploy-functions');
    expect(api.deployed['ref1']!.single.slug, 'send-push');
    await _tap(tester, 'wizard-next');

    await _tap(tester, 'instance-apply-signin');
    expect(api.authPatches['ref1']!.single['mailer_autoconfirm'], false);
    await _tap(tester, 'wizard-next');

    expect(find.textContaining('https://ref1.supabase.co'), findsOneWidget);
    await _tap(tester, 'instance-use-here');
    expect(store.value?.url, 'https://ref1.supabase.co');
    expect(store.value?.key, startsWith('sb_publishable_'));
  });

  testWidgets('a refused token is said in words; a failing migration is '
      'named and the retry resumes after it', (tester) async {
    final (:api, store: _) = await _pump(tester);
    await _tap(tester, 'backend-new-instance');
    api.unauthorized = true;
    await tester.enterText(find.byKey(const ValueKey('instance-token')), 'bad');
    await _tap(tester, 'instance-check-token');
    expect(find.textContaining('refused the token'), findsOneWidget);

    api.unauthorized = false;
    await _tap(tester, 'instance-check-token');
    await _tap(tester, 'wizard-next');
    await tester.enterText(find.byKey(const ValueKey('instance-project-name')), 'X');
    await tester.pumpAndSettle();
    await _tap(tester, 'instance-create-project');
    await _tap(tester, 'wizard-next');

    api
      ..failSqlContaining = 'table b'
      ..failMessage = 'permission denied';
    await _tap(tester, 'instance-install-schema');
    expect(find.textContaining('Stopped at 0002_b.sql: permission denied'), findsOneWidget);
    expect(api.sql['ref1'], hasLength(1));
    expect(api.recorded['ref1'], ['0001']);

    api.failSqlContaining = null;
    await _tap(tester, 'instance-install-schema');
    expect(api.sql['ref1'], hasLength(2), reason: 'resumed after 0001, not from scratch');
    expect(find.byKey(const ValueKey('instance-error')), findsNothing);
  });

  testWidgets('#1308 — an existing project with a foreign table is refused '
      'before anything runs, and another can be chosen', (tester) async {
    final (:api, store: _) = await _pump(tester);
    api
      ..projects.add((
        ref: 'old1',
        name: 'Shop',
        organizationId: 'org-1',
        region: 'eu-west-3',
        status: 'ACTIVE_HEALTHY',
      ))
      ..onQuery = (ref, sql) => sql.contains('server_version_num')
          ? [
              {'server_version_num': 170006, 'public_tables': 'orders'},
            ]
          : const [];
    await _tap(tester, 'backend-new-instance');
    await tester.enterText(find.byKey(const ValueKey('instance-token')), 'sbp_token');
    await _tap(tester, 'instance-check-token');
    await _tap(tester, 'wizard-next');
    await _tap(tester, 'instance-existing-old1');

    expect(find.byKey(const ValueKey('instance-readiness-needsAttention')),
        findsOneWidget);
    expect(find.textContaining('orders'), findsOneWidget);
    final next = tester.widget<ButtonStyleButton>(find.descendant(
        of: find.byKey(const ValueKey('wizard-next')),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        matchRoot: true));
    expect(next.onPressed, isNull, reason: 'nothing runs on this project');
    expect(api.sql, isEmpty);

    await _tap(tester, 'instance-choose-another');
    expect(find.byKey(const ValueKey('instance-existing-old1')), findsOneWidget);
  });

  testWidgets('#1308 — an existing project at this version needs no schema',
      (tester) async {
    final (:api, store: _) = await _pump(tester);
    api
      ..projects.add((
        ref: 'cur1',
        name: 'Current',
        organizationId: 'org-1',
        region: 'eu-west-3',
        status: 'ACTIVE_HEALTHY',
      ))
      ..markers['cur1'] = 2
      ..onQuery = (ref, sql) => sql.contains('server_version_num')
          ? [
              {'server_version_num': 170006, 'public_tables': 'a,b'},
            ]
          : const [];
    await _tap(tester, 'backend-new-instance');
    await tester.enterText(find.byKey(const ValueKey('instance-token')), 'sbp_token');
    await _tap(tester, 'instance-check-token');
    await _tap(tester, 'wizard-next');
    await _tap(tester, 'instance-existing-cur1');
    expect(find.byKey(const ValueKey('instance-readiness-current')),
        findsOneWidget);
    await _tap(tester, 'wizard-next');
    expect(find.text('Done'), findsWidgets);
    expect(api.sql, isEmpty);
  });
}
