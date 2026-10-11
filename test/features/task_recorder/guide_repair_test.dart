// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2310 — an older guide whose step names no page cannot be played: Start
// opens it in the guide editor instead, and once the author chooses the
// step's page there the same step opens its form.
import 'package:deskilo/features/task_recorder/data/guide_store.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/guide/guide_session.dart';
import 'package:deskilo/features/task_recorder/guide/task_guide.dart';
import 'package:deskilo/features/task_recorder/presentation/screens/task_wizard_screen.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fixtures/recording_fixtures.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('an unlinked guide is repaired in the editor before it plays', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final guides = GuideStore(
      backend: MemoryRecorderLogBackend(),
      accountNamespace: canaryNamespace,
    );
    final id = await tester.runAsync(
      () => guides.add(
        TaskGuide(
          actionContractVersion: actionContractVersion,
          title: 'Older guide',
          steps: const [GuideStep(id: 'g1', kind: GuideStepKind.manual)],
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        guideStoreProvider.overrideWithValue(guides),
        recorderScopeProvider.overrideWithValue(canaryScope),
        taskRecorderAvailableProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TaskWizardScreen()),
        GoRoute(
          path: '/me',
          builder: (_, _) => const Scaffold(body: Text('me page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_key('task-wizard-start-$id'));
    await tester.pumpAndSettle();
    expect(find.text('Guide draft'), findsOneWidget);
    expect(container.read(guideSessionProvider).run, isNull);
    expect(_key('guide-preview-g1'), findsNothing);
    expect(
      find.descendant(
        of: _key('guide-destination-g1-null'),
        matching: find.text(
          'Choose the page this step refers to in the guide editor.',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(_key('guide-destination-g1-null'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me · My profile').last);
    await tester.pumpAndSettle();
    expect(_key('guide-preview-g1'), findsOneWidget);

    await tester.tap(_key('guide-preview-g1'));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/me?tab=me');
    expect(find.text('me page'), findsOneWidget);
    final run = container.read(guideSessionProvider).run!;
    expect(run.guide.steps.single.destination, '/me?tab=me');
    container.read(guideSessionProvider.notifier).close();
  });
}
