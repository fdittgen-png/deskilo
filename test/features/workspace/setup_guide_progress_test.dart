// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 — the setup guide said for a screen reader, and kept to the plan.
// Progress is announced as text: the next milestone's "1 of 2 done" and
// the next action in one live sentence, each step's state in words, the
// next action's card in words, and its time as a range. Steps outside the
// levels the owner chose are not listed in the plan: they wait, folded and
// greyed, under "Add more to your space", "not in your setup", and "Add it"
// opens the levels screen; every counter of the plan reads the same with
// or without them.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_guide_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Map<String, Object?> _step(
  String id,
  String milestone,
  String state, {
  bool required = true,
  int minutes = 5,
}) => {
  'step': id,
  'milestone': milestone,
  'required': required,
  'state': state,
  'route': '/editor',
  'estimate_minutes': minutes,
};

/// Basics done, places next, services optional; with [outside], the kiosk
/// and VAT, whose features are off.
SetupStatus _status({bool outside = true, bool reached = false}) =>
    SetupStatus.fromJson({
      'steps': [
        _step('basics', 'bookable', 'ready'),
        _step(
          'places',
          'bookable',
          reached ? 'ready' : 'needs_configuration',
          minutes: 10,
        ),
        _step('services', 'money', 'needs_configuration', required: false),
        if (outside) ...[
          _step('kiosk', 'live', 'not_applicable', required: false),
          _step('vat', 'invoice', 'not_applicable'),
        ],
      ],
      'milestones': [
        {
          'milestone': 'bookable',
          'applies': true,
          'required': 2,
          'ready': reached ? 2 : 1,
          'reached': reached,
        },
      ],
    });

Future<List<String>> _pump(WidgetTester tester, SetupStatus status) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SetupGuideScreen()),
      for (final path in ['/editor', '/setup/levels'])
        GoRoute(
          path: path,
          builder: (_, _) {
            pushed.add(path);
            return const Scaffold();
          },
        ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        localSetup: FakeLocalSetupRepository(status: status),
      ),
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

Future<void> _unfold(WidgetTester tester, String group) async {
  await tester.tap(find.byKey(ValueKey('setup-guide-$group')));
  await tester.pumpAndSettle();
}

/// The words a screen reader reads for the widget keyed [key].
String _read(WidgetTester tester, String key) =>
    tester.getSemantics(find.byKey(ValueKey(key))).getSemanticsData().label;

void main() {
  testWidgets('progress is announced as text: the milestone and the next '
      'action, live; each step in words; the time as a range', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _status());

    final progress = find.byKey(const ValueKey('setup-guide-progress'));
    expect(
      tester.getSemantics(progress),
      isSemantics(
        label: 'Take bookings: 1 of 2 done · Next: Places on the plan',
        isLiveRegion: true,
      ),
    );
    // The next action's card, in words, with its time as a range.
    final next = _read(tester, 'setup-guide-next');
    expect(next, contains('Next'));
    expect(next, contains('Places on the plan'));
    expect(next, contains('about 10–20 min'));
    expect(find.text('About 10–20 min until: Take bookings'), findsOneWidget);

    // Every step's state is a word, whatever its icon.
    await _unfold(tester, 'done');
    expect(_read(tester, 'setup-step-basics'), contains('Done'));
    await _unfold(tester, 'optional');
    expect(_read(tester, 'setup-step-services'), contains('To do'));
    await _unfold(tester, 'add-more');
    expect(_read(tester, 'setup-step-kiosk'), contains('Not in your setup'));
    semantics.dispose();
  });

  testWidgets('every chosen milestone reached: the announcement says so', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _status(reached: true));
    expect(
      tester.getSemantics(find.byKey(const ValueKey('setup-guide-progress'))),
      isSemantics(
        label: 'Your space has everything you chose.',
        isLiveRegion: true,
      ),
    );
    // What the space could add stays within reach.
    expect(find.byKey(const ValueKey('setup-guide-add-more')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('steps outside the chosen levels are not in the plan; Add it '
      'opens the levels', (tester) async {
    final pushed = await _pump(tester, _status());
    expect(find.text('Add more to your space (2)'), findsOneWidget);
    expect(find.text('More for your space (1)'), findsOneWidget);
    expect(find.text('Kiosk and badges'), findsNothing, reason: 'folded');
    expect(find.text('VAT'), findsNothing, reason: 'not in the plan');

    await _unfold(tester, 'add-more');
    expect(find.text('Kiosk and badges'), findsOneWidget);
    expect(find.textContaining('Not in your setup · '), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('setup-step-add-kiosk')));
    await tester.pumpAndSettle();
    expect(pushed, ['/setup/levels']);
  });

  testWidgets('the plan counts the same with or without the steps outside '
      'it', (tester) async {
    List<String> counters() => [
      for (final key in ['setup-guide-progress', 'setup-guide-optional'])
        tester.getSemantics(find.byKey(ValueKey(key))).label,
      find
          .byType(Chip)
          .evaluate()
          .map((e) => ((e.widget as Chip).label as Text).data)
          .join(),
    ];
    final semantics = tester.ensureSemantics();
    await _pump(tester, _status(outside: false));
    final without = counters();
    expect(find.byKey(const ValueKey('setup-guide-add-more')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, _status());
    expect(counters(), without);
    semantics.dispose();
  });
}
