// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2343 — a build without a default server (F-Droid) starts on a choice:
// the reference server, an existing server tested first, or a new one the
// instance wizard builds. The choice is stored and nothing else is
// contacted; no Supabase client exists while these screens run, so any
// provider that reached for one would fail these tests.
import 'package:deskilo/app/app_initializer.dart';
import 'package:deskilo/app/server_choice_app.dart';
import 'package:deskilo/core/backend/backend_config.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/instance/instance_bundle.dart';
import 'package:deskilo/core/instance/instance_bundle_asset.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase_management.dart';

const _bundleJson = '''
{"schema":[{"name":"0001_a.sql","sql":"create table a();"}],
 "functions":[{"slug":"send-push","verifyJwt":true,"files":[{"name":"index.ts","content":"x"}]}]}
''';

/// A probe every candidate passes.
class _UsableProbe implements BackendProbeTransport {
  @override
  Future<void> readOneWorkspace() async {}
  @override
  Future<int?> readVersion() async => requiredSchemaVersion;
  @override
  Future<void> dispose() async {}
}

Future<({InMemoryBackendSettingsStore store, List<int> chosen})> _pump(
  WidgetTester tester, {
  FakeSupabaseManagement? api,
}) async {
  final store = InMemoryBackendSettingsStore();
  final chosen = <int>[];
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        enabledFeaturesSyncProvider.overrideWithValue(ServerChoiceApp.features),
        backendProbeTransportProvider.overrideWithValue((_) => _UsableProbe()),
        supabaseManagementFactoryProvider.overrideWithValue(
          (_) => api ?? FakeSupabaseManagement(),
        ),
        instanceBundleLoaderProvider.overrideWithValue(
          () async => parseInstanceBundle(_bundleJson),
        ),
        instanceDoctorRunnerProvider.overrideWithValue(
          (api, ref) async => const [
            DoctorFinding(DoctorLevel.ok, 'Site URL', 'matches'),
          ],
        ),
      ],
      child: ServerChoiceApp(store: store, onChosen: () => chosen.add(1)),
    ),
  );
  await tester.pumpAndSettle();
  return (store: store, chosen: chosen);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('whether the first start asks', () {
    test('a build with a default never asks', () async {
      expect(
        await needsServerChoice(hasDefault: true, readStored: () async => null),
        isFalse,
      );
    });

    test('a build without one asks until a server is stored', () async {
      expect(
        await needsServerChoice(
          hasDefault: false,
          readStored: () async => null,
        ),
        isTrue,
      );
      expect(
        await needsServerChoice(
          hasDefault: false,
          readStored: () async => referenceEndpoint,
        ),
        isFalse,
      );
    });

    test('the reference server is named, and is the default of this '
        'build', () {
      expect(referenceEndpoint.url, BackendConfig.referenceUrl);
      expect(isReferenceBackend('${BackendConfig.referenceUrl}/'), isTrue);
      expect(isReferenceBackend('https://mycowork.supabase.co'), isFalse);
      // Tests run without the define: the store builds' behaviour.
      expect(BackendConfig.hasDefault, isTrue);
      expect(compiledDefaultEndpoint?.url, BackendConfig.supabaseUrl);
    });
  });

  testWidgets('three ways, and the reference server is offered once', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('server-choice-reference')), findsOne);
    expect(find.byKey(const ValueKey('server-choice-existing')), findsOne);
    expect(find.byKey(const ValueKey('server-choice-new')), findsOne);
    expect(
      find.byKey(const ValueKey('backend-mode-default')),
      findsNothing,
      reason: 'the form does not offer the reference a second time',
    );
  });

  testWidgets('the reference server is stored once, and the app starts on it', (
    tester,
  ) async {
    final (:store, :chosen) = await _pump(tester);
    await _tap(tester, 'server-choice-use-reference');
    expect(store.value?.url, BackendConfig.referenceUrl);
    expect(store.value?.key, BackendConfig.referenceKey);
    expect(chosen, [1]);
    await _tap(tester, 'server-choice-use-reference');
    expect(chosen, [1], reason: 'one choice per start');
  });

  testWidgets('an existing server is stored only once its test passed', (
    tester,
  ) async {
    final (:store, :chosen) = await _pump(tester);
    await _tap(tester, 'backend-mode-operator');
    await tester.enterText(
      find.byKey(const ValueKey('backend-url-field')),
      'https://mycowork.supabase.co',
    );
    await tester.enterText(
      find.byKey(const ValueKey('backend-key-field')),
      'sb_publishable_0123456789abcdefghij',
    );
    await tester.pump();
    expect(chosen, isEmpty);
    await _tap(tester, 'backend-test');
    await _tap(tester, 'backend-save');
    expect(store.value?.url, 'https://mycowork.supabase.co');
    expect(chosen, [1]);
  });

  testWidgets('a new server is built by the wizard, before any server '
      'exists, and the app starts on it', (tester) async {
    final api = FakeSupabaseManagement()..readyAfterPolls = 1;
    final (:store, :chosen) = await _pump(tester, api: api);
    await _tap(tester, 'server-choice-new-instance');
    await tester.enterText(
      find.byKey(const ValueKey('instance-token')),
      'sbp_token',
    );
    await _tap(tester, 'instance-check-token');
    await _tap(tester, 'wizard-next');
    await tester.enterText(
      find.byKey(const ValueKey('instance-project-name')),
      'Pézenas',
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'instance-create-project');
    // The project is polled every five seconds until it is up.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(api.projects.single.name, 'Pézenas');
    await _tap(tester, 'wizard-next');
    await _tap(tester, 'instance-install-schema');
    await _tap(tester, 'wizard-next');
    await _tap(tester, 'instance-deploy-functions');
    await _tap(tester, 'wizard-next');
    await tester.enterText(
      find.byKey(const ValueKey('instance-owner-email')),
      'owner@example.org',
    );
    await _tap(tester, 'instance-apply-signin');
    await _tap(tester, 'wizard-next');
    await _tap(tester, 'instance-doctor-run');
    expect(chosen, isEmpty);
    await _tap(tester, 'instance-use-here');
    expect(api.deployed['ref1']!.single.slug, 'send-push');
    expect(store.value?.url, 'https://ref1.supabase.co');
    expect(chosen, [1]);
  });

  test('the choice screens show no help links: the guide is a route of '
      'the real app', () {
    expect(
      ServerChoiceApp.features,
      isNot(contains(WorkspaceFeature.formHelpHints)),
    );
    expect(ServerChoiceApp.features, contains(WorkspaceFeature.instanceWizard));
  });
}
