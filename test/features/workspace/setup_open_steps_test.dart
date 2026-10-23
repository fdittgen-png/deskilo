// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2870 — the Open step pages for the basics, the hours and the places.
// Basics: prefilled from the workspace row, saved through the locale and
// language writes, the preview redrawn in the chosen locale before saving.
// Hours: the availability screen's own sections write the open weekdays,
// and the week strip says each day in words; the next three closures from
// today. Places: each level's counts and plan, what a member can book, and
// the editor one tap away. Every page is one column on a phone.
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/features/plan/domain/floor_plan_repository.dart';
import 'package:deskilo/features/plan/presentation/widgets/setup_places_step.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

Future<void> _pump(
  WidgetTester tester,
  String stepId, {
  FakeWorkspaceRepository? repo,
  FloorPlanRepository? plan,
}) async {
  await pumpApp(
    tester,
    SetupStepScreen(stepId: stepId, placesStep: SetupPlacesStep.new),
    size: _phone,
    overrides: standardTestOverrides(
      workspace: repo ?? FakeWorkspaceRepository.withWorkspace(),
      floorPlan: plan,
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void _oneColumn(WidgetTester tester) {
  expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
  expect(find.byKey(const ValueKey('setup-step-two-panes')), findsNothing);
  expect(tester.takeException(), isNull);
}

ClosureDay _closure(String id, DateTime day) =>
    ClosureDay(id: id, workspaceId: 'ws-1', day: day, reason: 'Reason $id');

void main() {
  group('basics', () {
    testWidgets('prefilled from the workspace row', (tester) async {
      await _pump(tester, 'basics');
      expect(_text(tester, 'setup-basics-name'), isNotEmpty);
      expect(
        find.byKey(const ValueKey('setup-basics-country-DE')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('workspaceSettingsTimezone')),
            )
            .controller!
            .text,
        'Europe/Berlin',
      );
      expect(find.text('EUR · €'), findsOneWidget);
    });

    testWidgets('the preview follows the form before anything is saved, '
        'and save writes the locale and the language', (tester) async {
      final repo = FakeWorkspaceRepository.withWorkspace();
      await _pump(tester, 'basics', repo: repo);
      // en + DE formats as en_GB: the euro before the amount.
      expect(_text(tester, 'setup-basics-preview-money'), '€1,234.50');
      expect(_text(tester, 'setup-basics-preview-time'), contains('UTC+02:00'));

      await tester.tap(find.byKey(const ValueKey('setup-basics-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Français').last);
      await tester.pumpAndSettle();
      expect(
        _text(tester, 'setup-basics-preview-money'),
        allOf(contains('1'), contains('234,50'), endsWith('€')),
      );
      expect(repo.lastLocaleUpdate, isNull, reason: 'nothing saved yet');

      await tester.tap(find.byKey(const ValueKey('setup-basics-save')));
      await tester.pumpAndSettle();
      expect(repo.lastLocaleUpdate, ['ws-1', 'DE', 'EUR', 'Europe/Berlin']);
      expect(repo.workspaces.first.defaultLocale, 'fr');
    });

    testWidgets('one column on a phone', (tester) async {
      await _pump(tester, 'basics');
      _oneColumn(tester);
    });
  });

  group('hours', () {
    FakeWorkspaceRepository seeded() {
      final repo = FakeWorkspaceRepository.withWorkspace()
        ..openWeekdays['ws-1'] = [1, 2, 3];
      repo.closureDays.addAll([
        _closure('past', DateTime(2026, 4, 30)),
        _closure('c1', DateTime(2026, 5, 14)),
        _closure('c3', DateTime(2026, 8, 15)),
        _closure('c2', DateTime(2026, 5, 25)),
        _closure('c4', DateTime(2026, 12, 25)),
      ]);
      return repo;
    }

    testWidgets('the week strip says the stored week in words and cells, '
        'and the next three closures follow from today', (tester) async {
      await _pump(tester, 'hours', repo: seeded());
      expect(_text(tester, 'setup-week-words-4'), 'Closed');
      expect(_text(tester, 'setup-week-words-1'), isNot('Closed'));
      expect(
        find.byKey(const ValueKey('setup-week-cell-1-9-open')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setup-week-cell-1-18-closed')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setup-week-cell-4-9-closed')),
        findsOneWidget,
      );

      final shown = [
        for (final id in ['past', 'c1', 'c2', 'c3', 'c4'])
          if (find
              .byKey(ValueKey('setup-hours-closure-$id'))
              .evaluate()
              .isNotEmpty)
            id,
      ];
      expect(shown, ['c1', 'c2', 'c3']);
      final c1 = tester.getRect(
        find.byKey(const ValueKey('setup-hours-closure-c1')),
      );
      final c2 = tester.getRect(
        find.byKey(const ValueKey('setup-hours-closure-c2')),
      );
      expect(c2.top, greaterThan(c1.top), reason: 'in date order');
    });

    testWidgets('a weekday chip stores the open days and the strip '
        'opens that day', (tester) async {
      final repo = seeded();
      await _pump(tester, 'hours', repo: repo);
      await tester.tap(
        find.byKey(const ValueKey('availability-filter-chip-4')),
      );
      await tester.pumpAndSettle();
      expect(repo.openWeekdays['ws-1'], [1, 2, 3, 4]);
      expect(_text(tester, 'setup-week-words-4'), isNot('Closed'));
      expect(
        find.byKey(const ValueKey('setup-week-cell-4-9-open')),
        findsOneWidget,
      );
    });

    testWidgets('no closure ahead says so', (tester) async {
      await _pump(tester, 'hours');
      expect(
        find.byKey(const ValueKey('setup-hours-no-closures')),
        findsOneWidget,
      );
    });

    testWidgets('one column on a phone', (tester) async {
      await _pump(tester, 'hours', repo: seeded());
      _oneColumn(tester);
    });
  });

  group('places', () {
    FakeFloorPlanRepository seeded() =>
        FakeFloorPlanRepository()..seedSmallPlan();

    testWidgets('each level counts its rooms, desks and seats beside its '
        'plan, and the preview lists what a member can book', (tester) async {
      final plan = seeded();
      await _pump(tester, 'places', plan: plan);
      final level = plan.levels.single;
      expect(
        _text(tester, 'setup-places-counts-${level.id}'),
        '1 room · 1 desk · 1 seat',
      );
      expect(
        find.byKey(const ValueKey('setup-plan-thumbnail')),
        findsOneWidget,
      );
      final seat = plan.seats.single;
      final row = find.byKey(ValueKey('setup-places-bookable-seat-${seat.id}'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text(seat.name)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setup-places-preview-none')),
        findsNothing,
      );
    });

    testWidgets('a whole office joins what a member can book', (tester) async {
      final plan = seeded();
      plan.offices[0] = plan.offices[0].copyWith(bookableAsWhole: true);
      await _pump(tester, 'places', plan: plan);
      expect(
        find.byKey(
          ValueKey('setup-places-bookable-office-${plan.offices[0].id}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('several sites: each level under its own site, and a '
        'template can start the plan', (tester) async {
      final plan = seeded();
      plan.levels[0] = plan.levels[0].copyWith(siteId: 'site-lyon');
      await pumpApp(
        tester,
        const Scaffold(
          body: SetupPlacesStep(
            sites: {'site-paris': 'Paris', 'site-lyon': 'Lyon'},
            libraryOn: true,
          ),
        ),
        size: _phone,
        overrides: standardTestOverrides(floorPlan: plan),
      );
      await tester.pumpAndSettle();
      final lyon = tester.getRect(
        find.byKey(const ValueKey('setup-places-site-site-lyon')),
      );
      final paris = tester.getRect(
        find.byKey(const ValueKey('setup-places-site-site-paris')),
      );
      final level = tester.getRect(
        find.byKey(ValueKey('setup-places-level-${plan.levels[0].id}')),
      );
      expect(paris.top, lessThan(lyon.top));
      expect(level.top, greaterThanOrEqualTo(lyon.bottom));
      expect(
        find.byKey(const ValueKey('setup-places-template')),
        findsOneWidget,
      );
    });

    testWidgets('no level yet: the step says so and nothing is bookable', (
      tester,
    ) async {
      await _pump(tester, 'places', plan: FakeFloorPlanRepository());
      expect(find.byKey(const ValueKey('setup-places-empty')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('setup-places-preview-none')),
        findsOneWidget,
      );
    });

    testWidgets('open the editor goes to the editor', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SetupStepScreen(
              stepId: 'places',
              placesStep: SetupPlacesStep.new,
            ),
          ),
          GoRoute(
            path: '/editor',
            builder: (_, _) => const Text('editor screen'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await pumpApp(
        tester,
        null,
        router: router,
        size: _phone,
        overrides: standardTestOverrides(floorPlan: seeded()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setup-places-open-editor')));
      await tester.pumpAndSettle();
      expect(find.text('editor screen'), findsOneWidget);
    });

    testWidgets('one column on a phone', (tester) async {
      await _pump(tester, 'places', plan: seeded());
      _oneColumn(tester);
    });
  });
}
