// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 — the setup guide shows the one next action first, opens the
// screen where a step is done, folds what can wait, and says when every
// chosen milestone is reached. With the guide on, the settings cards give
// way to its resume banner.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_guide_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/local_setup_views.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

SetupStatus _status({bool done = false}) => SetupStatus.fromJson({
  'steps': [
    {
      'step': 'basics',
      'milestone': 'bookable',
      'required': true,
      'state': 'ready',
      'route': '/workspace-settings',
    },
    {
      'step': 'places',
      'milestone': 'bookable',
      'required': true,
      'state': done ? 'ready' : 'needs_configuration',
      'route': '/editor',
      'estimate_minutes': 10,
    },
    {
      'step': 'services',
      'milestone': 'money',
      'required': false,
      'state': 'needs_configuration',
      'route': '/services',
    },
  ],
  'milestones': [
    {
      'milestone': 'bookable',
      'applies': true,
      'required': 2,
      'ready': done ? 2 : 1,
      'reached': done,
    },
  ],
});

Future<List<String>> _pump(
  WidgetTester tester,
  SetupStatus status, {
  Widget? home,
  Set<WorkspaceFeature>? features,
  Map<String, SetupEstimate> observed = const {},
}) async {
  final pushed = <String>[];
  GoRoute target(String path) => GoRoute(
    path: path,
    builder: (_, _) {
      pushed.add(path);
      return const Scaffold();
    },
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home ?? const SetupGuideScreen()),
      target('/editor'),
      target('/services'),
      target('/setup'),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          localSetup: FakeLocalSetupRepository(status: status)
            ..timingRanges = observed,
        ),
        if (features != null)
          enabledFeaturesSyncProvider.overrideWithValue(features),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  return pushed;
}

void main() {
  testWidgets('the next action comes first and opens where it is done', (
    tester,
  ) async {
    final pushed = await _pump(tester, _status());
    expect(find.text('Places on the plan'), findsOneWidget);
    expect(find.text('about 10–20 min'), findsOneWidget);
    expect(find.textContaining('Take bookings · 1 of 2 done'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('setup-guide-next-places')));
    await tester.pump();
    await tester.pump();
    expect(pushed, ['/editor']);
  });

  testWidgets('a step the instance has timed often enough says the observed '
      'range, and the milestone line follows it', (tester) async {
    await _pump(tester, _status(), observed: {'places': (low: 4, high: 7)});
    expect(find.text('about 4–7 min'), findsOneWidget);
    expect(find.text('about 10–20 min'), findsNothing);
    expect(
      find.text('About 4–7 min until: Take bookings'),
      findsOneWidget,
    );
  });

  testWidgets('without observations the range is the catalogue rule', (
    tester,
  ) async {
    await _pump(tester, _status());
    expect(find.text('about 10–20 min'), findsOneWidget);
    expect(
      find.text('About 10–20 min until: Take bookings'),
      findsOneWidget,
    );
  });

  testWidgets('what can wait is folded, by group', (tester) async {
    await _pump(tester, _status());
    expect(find.byKey(const ValueKey('setup-guide-optional')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-guide-done')), findsOneWidget);
    expect(find.text('Services'), findsNothing, reason: 'folded until opened');
  });

  testWidgets('every chosen milestone reached: the guide says so', (
    tester,
  ) async {
    await _pump(tester, _status(done: true));
    expect(find.byKey(const ValueKey('setup-guide-all-done')), findsOneWidget);
  });

  testWidgets(
    'with the guide on, the settings show its banner, not the cards',
    (tester) async {
      final pushed = await _pump(
        tester,
        _status(),
        home: Scaffold(body: Column(children: setupReadinessCards('ws-1'))),
        features: {WorkspaceFeature.setupGuide},
      );
      expect(find.byKey(const ValueKey('setup-resume-banner')), findsOneWidget);
      expect(find.textContaining('Next: Places on the plan'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('setup-resume-open')));
      await tester.pump();
      await tester.pump();
      expect(pushed, ['/setup']);
    },
  );

  testWidgets('with the guide off, the settings keep their cards', (
    tester,
  ) async {
    await _pump(
      tester,
      _status(),
      home: Scaffold(body: Column(children: setupReadinessCards('ws-1'))),
      features: const {},
    );
    expect(find.byKey(const ValueKey('setup-resume-banner')), findsNothing);
  });
}
