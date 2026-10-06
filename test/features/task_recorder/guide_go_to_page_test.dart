// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: a guide step that happens on a page offers "Go to page" — the
// page is worked out from what the recorder knows (the screen seam's page, or
// the page the guide last opened), a page that needs an id offers none, the
// button opens the page without entering anything, and it is gone once the
// person is there.
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/guide/guide_session.dart';
import 'package:deskilo/features/task_recorder/guide/task_guide.dart';
import 'package:deskilo/features/task_recorder/presentation/guide_host/guide_host.dart';
import 'package:deskilo/features/task_recorder/presentation/guide_host/guide_step_text.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fixtures/recording_fixtures.dart';

GuideStep _step(String id, String action, {String? target}) => GuideStep(
  id: id,
  kind: GuideStepKind.perform,
  action: action,
  target: target,
);

void main() {
  group('the page of a step', () {
    test('a screen seam names its page', () {
      final s = _step('g1', RecorderActions.calendarSwitchView);
      expect(guideStepRoute([s], s), '/calendar');
      final r = _step('g1', RecorderActions.openReserve);
      expect(guideStepRoute([r], r), '/reserve');
    });

    test('a generic step happens on the page the guide last opened', () {
      final open = _step('g1', RecorderActions.uiOpenScreen, target: '/me');
      final tap = _step('g2', RecorderActions.uiTap, target: 'demo-save');
      expect(guideStepRoute([open, tap], tap), '/me');
      expect(guideStepRoute([open, tap], open), '/me');
    });

    test('a page that needs an id offers none, and neither does a step '
        'before any page', () {
      final open = _step(
        'g1',
        RecorderActions.uiOpenScreen,
        target: '/member/:memberId',
      );
      final tap = _step('g2', RecorderActions.uiTap, target: 'demo-save');
      expect(guideStepRoute([open, tap], tap), isNull);
      expect(guideStepRoute([tap], tap), isNull);
    });

    test('a recovery step belongs to the page of the step it recovers', () {
      final recovery = _step('g1r1', RecorderActions.uiTap, target: 'retry');
      final main = GuideStep(
        id: 'g1',
        kind: GuideStepKind.perform,
        action: RecorderActions.calendarSwitchView,
        recovery: [recovery],
      );
      expect(guideStepRoute([main], recovery), '/calendar');
    });
  });

  testWidgets('Go to page opens the page, and leaves once you are there', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/calendar',
          builder: (_, _) => const Scaffold(body: Text('calendar page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final c = ProviderContainer(
      overrides: [
        recorderScopeProvider.overrideWith((ref) => canaryScope),
        taskRecorderAvailableProvider.overrideWith((ref) => true),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Stack(
            children: [
              child!,
              Positioned.fill(child: GuideHostLayer(router: router)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    c
        .read(guideSessionProvider.notifier)
        .start(
          TaskGuide(
            actionContractVersion: actionContractVersion,
            title: 'Switch the view',
            steps: [_step('g1', RecorderActions.calendarSwitchView)],
          ),
        );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final go = find.byKey(const ValueKey('guide-host-go-to-page'));
    expect(go, findsOneWidget);
    expect(find.text('home'), findsOneWidget);

    await tester.tap(go);
    await tester.pumpAndSettle();
    expect(find.text('calendar page'), findsOneWidget);
    // Nothing was entered for the person, and the button left with the trip.
    expect(go, findsNothing);
    expect(c.read(guideSessionProvider).run!.statusOf('g1').name, 'pending');
    c.read(guideSessionProvider.notifier).close();
    await tester.pumpWidget(const SizedBox());
  });
}
