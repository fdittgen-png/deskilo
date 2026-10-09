// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: a guide step that happens on a page offers "Go to page" — the
// page is worked out from an explicit reference or legacy context. The link
// remains usable, and an already-open form is preserved when highlighting.
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

    test('a page that needs an id opens its chooser; no invented destination '
        'before any page', () {
      final open = _step(
        'g1',
        RecorderActions.uiOpenScreen,
        target: '/member/:memberId',
      );
      final tap = _step('g2', RecorderActions.uiTap, target: 'demo-save');
      expect(guideStepRoute([open, tap], tap), '/members');
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

  testWidgets('Go to page opens the page and remains available', (
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
        GoRoute(
          path: '/members',
          builder: (_, _) => const Scaffold(body: Text('choose a member')),
        ),
        GoRoute(
          path: '/member/:memberId',
          builder: (_, _) =>
              const Scaffold(body: TextField(key: ValueKey('me-workspaces'))),
        ),
        GoRoute(
          path: '/roles',
          builder: (_, _) =>
              const Scaffold(body: TextField(key: ValueKey('me-workspaces'))),
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
    // The destination stays available without completing the action.
    expect(go, findsOneWidget);
    expect(c.read(guideSessionProvider).run!.statusOf('g1').name, 'pending');
    // A navigation instruction can be satisfied even when its page is
    // already open; the following form action must remain pending.
    c
        .read(guideSessionProvider.notifier)
        .start(
          TaskGuide(
            actionContractVersion: actionContractVersion,
            steps: [
              _step('g1', RecorderActions.uiOpenScreen, target: '/calendar'),
              _step('g2', RecorderActions.calendarSwitchView),
            ],
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guide-host-show-me')));
    await tester.pumpAndSettle();
    expect(c.read(guideSessionProvider).run!.statusOf('g1').name, 'done');
    expect(c.read(guideSessionProvider).run!.current!.id, 'g2');
    expect(c.read(guideSessionProvider).run!.statusOf('g2').name, 'pending');

    // A private detail route is already open. Its recorded public reference
    // is the chooser, but the mounted control can be highlighted in place.
    router.go('/member/example');
    await tester.pumpAndSettle();
    c
        .read(guideSessionProvider.notifier)
        .start(
          TaskGuide(
            actionContractVersion: actionContractVersion,
            steps: const [
              GuideStep(
                id: 'g1',
                kind: GuideStepKind.perform,
                action: RecorderActions.uiCommitField,
                target: 'me-workspaces',
                destination: '/members',
              ),
            ],
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guide-host-show-me')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/member/example');
    expect(find.byKey(const ValueKey('guide-host-ring')), findsOneWidget);
    expect(c.read(guideSessionProvider).run!.statusOf('g1').name, 'pending');
    router.go('/roles');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.byKey(const ValueKey('guide-host-ring')),
      findsNothing,
      reason: 'A reused control key on another form is not the reference.',
    );
    await tester.tap(find.byKey(const ValueKey('guide-host-show-me')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/members');
    c.read(guideSessionProvider.notifier).close();
    await tester.pumpWidget(const SizedBox());
  });
}
