// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3076 — the goal the status marks as applying is said on the hub and on
// the check page, with a way to change it; a step page offers "Next step"
// beside the way back, and "Done" when no step is left.
import 'dart:async';

import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_guide_screen.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_launch_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/setup_return_bar.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Map<String, Object> _step(String id, String milestone, String state) => {
  'step': id,
  'milestone': milestone,
  'required': true,
  'state': state,
  'route': '/page-$id',
};

Map<String, Object> _milestone(String id, {required bool applies}) => {
  'milestone': id,
  'applies': applies,
  'required': 1,
  'ready': 0,
  'reached': false,
};

SetupStatus _status({List<String> open = const ['places', 'tiers']}) =>
    SetupStatus.fromJson({
      'steps': [
        _step(
          'basics',
          'bookable',
          open.contains('basics') ? 'needs_configuration' : 'ready',
        ),
        _step(
          'places',
          'bookable',
          open.contains('places') ? 'needs_configuration' : 'ready',
        ),
        _step(
          'tiers',
          'money',
          open.contains('tiers') ? 'needs_configuration' : 'ready',
        ),
      ],
      'milestones': [
        _milestone('bookable', applies: true),
        _milestone('money', applies: true),
        _milestone('invoice', applies: false),
      ],
    });

Future<GoRouter> _pump(WidgetTester tester, SetupStatus status) async {
  final router = GoRouter(
    initialLocation: '/setup',
    routes: [
      GoRoute(path: '/setup', builder: (_, _) => const SetupGuideScreen()),
      GoRoute(
        path: '/setup/launch',
        builder: (_, _) => const SetupLaunchScreen(),
      ),
      GoRoute(
        path: '/setup/levels',
        builder: (_, _) => const Scaffold(body: Text('levels page')),
      ),
      GoRoute(
        path: '/setup/step/:id',
        builder: (_, state) => Scaffold(
          appBar: AppBar(),
          body: Text('step ${state.pathParameters['id']}'),
        ),
      ),
      for (final id in ['basics', 'places', 'tiers'])
        GoRoute(
          path: '/page-$id',
          builder: (_, _) => Scaffold(appBar: AppBar(), body: Text('page $id')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        localSetup: FakeLocalSetupRepository(status: status),
      ),
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            SetupReturnBar(router: router, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  test('the goal is the last milestone the status marks as applying', () {
    expect(_status().goal?.milestone, 'money');
    expect(const SetupStatus().goal, isNull);
  });

  test('the step after one is the next open step in guide order', () {
    final status = _status();
    expect(status.stepAfter('places')?.step, 'tiers');
    expect(status.stepAfter('tiers'), isNull);
    expect(_status(open: ['places']).stepAfter('places'), isNull);
  });

  testWidgets('the hub says the goal and changing it opens the levels', (
    tester,
  ) async {
    await _pump(tester, _status());
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('setup-guide-goal')),
        matching: find.text('Your goal: Ready for money'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('setup-guide-goal-change')));
    await tester.pumpAndSettle();
    expect(find.text('levels page'), findsOneWidget);
  });

  testWidgets('the check page names the goal that blocks opening', (
    tester,
  ) async {
    final router = await _pump(tester, _status());
    unawaited(router.push('/setup/launch'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('setup-launch-goal')),
        matching: find.text('Because your goal is Ready for money.'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('setup-launch-goal-change')));
    await tester.pumpAndSettle();
    expect(find.text('levels page'), findsOneWidget);
  });

  testWidgets('a step page offers the next step beside the way back; with '
      'none left it says Done and returns to the guide', (tester) async {
    await _pump(tester, _status());
    await tester.tap(find.byKey(const ValueKey('setup-guide-next-places')));
    await tester.pumpAndSettle();
    expect(find.text('page places'), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-return')), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('setup-next-step')));
    await tester.pumpAndSettle();
    expect(find.text('page tiers'), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-return-bar')), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('setup-next-step')));
    await tester.pumpAndSettle();
    expect(find.byType(SetupGuideScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-return-bar')), findsNothing);
  });

  testWidgets('a step opened from the check page (Fix it), not from the guide, '
      'carries the way back and the next step, read from its route', (
    tester,
  ) async {
    final router = await _pump(tester, _status());
    unawaited(router.push('/setup/launch'));
    await tester.pumpAndSettle();
    unawaited(router.push('/setup/step/places'));
    await tester.pumpAndSettle();
    expect(find.text('step places'), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-return-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-return')), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('setup-next-step')));
    await tester.pumpAndSettle();
    expect(find.text('page tiers'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('the last open step opened by its route says Done, and a page '
      'that is not a step page carries no bar', (tester) async {
    final router = await _pump(tester, _status(open: ['tiers']));
    unawaited(router.push('/setup/step/tiers'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    unawaited(router.push('/setup/levels'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setup-return-bar')), findsNothing);
  });
}
