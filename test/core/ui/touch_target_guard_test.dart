// SPDX-License-Identifier: MIT
//
// #211 (epic #205): touch-target guard for the compact header controls.
// Each audited surface (Plan tab, Calendar tab incl. the day timeline,
// Reserve hub) is pumped with every chip row visible (two levels +
// half-day granularity) and every interactive header element is measured.
//
// Floors: [kMinInteractiveDimension] (48dp) is the Material minimum
// interactive size — IconButtons and SegmentedButtons own their whole hit
// box, so they must meet it in both axes. ChoiceChips assert a pragmatic
// 44dp floor instead (the iOS HIG minimum): their padded redirecting hit
// box measures 48 here too, but header chips legitimately sit inside
// FittedBox(scaleDown) rows where tight widths may scale them slightly —
// 44 keeps the guard flake-free while still failing loudly for any
// regression to the old 40dp compact rows.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/calendar/day_timeline_test.dart' show addSecondLevel;
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

/// Pragmatic chip floor — see the header comment for the rationale.
const double _chipFloor = 44;

/// Pumps the app on the Plan tab with two levels (level chips visible)
/// and half-day granularity (Morning/Afternoon/Day chips visible), open
/// every day so no banner shifts the header.
Future<void> pumpApp(WidgetTester tester) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  addSecondLevel(plans);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7]
    ..bookingGranularities['ws-1'] = BookingGranularity.halfDay;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(floorPlan: plans, workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Asserts the touch-target floors on everything currently on screen.
void expectTouchTargets(WidgetTester tester, {required String surface}) {
  for (final element in find.byType(ChoiceChip).evaluate()) {
    expect(
      element.size!.height,
      greaterThanOrEqualTo(_chipFloor),
      reason: '$surface: a ChoiceChip hit area is below ${_chipFloor}dp',
    );
  }
  for (final element in find.byType(IconButton).evaluate()) {
    expect(
      element.size!.height,
      greaterThanOrEqualTo(kMinInteractiveDimension),
      reason: '$surface: an IconButton is shorter than the Material minimum',
    );
    expect(
      element.size!.width,
      greaterThanOrEqualTo(kMinInteractiveDimension),
      reason: '$surface: an IconButton is narrower than the Material minimum',
    );
  }
  for (final element in find.bySubtype<SegmentedButton>().evaluate()) {
    expect(
      element.size!.height,
      greaterThanOrEqualTo(kMinInteractiveDimension),
      reason: '$surface: a SegmentedButton is shorter than the Material '
          'minimum',
    );
  }
}

void main() {
  testWidgets(
      'Plan tab: level chips, half-day chips and the view toggle all meet '
      'the touch-target floors', (tester) async {
    await pumpApp(tester);

    // The audit is only meaningful when the compact controls are there.
    expect(find.byType(ChoiceChip), findsAtLeastNWidgets(5));
    expect(find.byKey(const ValueKey('plan-view-switch')), findsOneWidget);

    expectTouchTargets(tester, surface: 'plan');
  });

  testWidgets(
      'Calendar tab: month navigation, Mine/Everyone, the view toggle and '
      'the timeline level chips all meet the touch-target floors',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-view-switch')),
      findsOneWidget,
    );
    expectTouchTargets(tester, surface: 'calendar list');

    // Timeline view adds the day timeline's own level-chip row.
    await tester.tap(find.byIcon(Icons.view_timeline_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsAtLeastNWidgets(2));
    expectTouchTargets(tester, surface: 'calendar timeline');
  });

  testWidgets(
      'Reserve hub: date pills, half-day window chips, level chips and the '
      'Plan/Day/Week toggle all meet the touch-target floors',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Reserve'));
    await tester.pumpAndSettle();

    // Date pills + Morning/Afternoon/Full day + two level chips.
    expect(find.byType(ChoiceChip), findsAtLeastNWidgets(5));
    expect(find.byKey(const ValueKey('reserve-view-switch')), findsOneWidget);

    expectTouchTargets(tester, surface: 'reserve hub');
  });
}
