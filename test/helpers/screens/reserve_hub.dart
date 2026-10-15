// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in reserve_hub_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_floor_plan_repository.dart';
import '../fake_reservation_repository.dart';
import '../mock_providers.dart';
import 'day_timeline.dart' show addSecondLevel;

/// Pumps the app and enters the Reserve hub through the bar's raised
/// centre button (#207), on the seeded small plan (one seat 'A1' =
/// seat-4 at grid (2,2)). Open every day by default so booking flows
/// never hit the closed-day gate (#186) — pass [openWeekdays] to test it.
Future<FakeReservationRepository> pumpHub(
  WidgetTester tester, {
  List<Reservation> seed = const [],
  BookingGranularity? granularity,
  List<int> openWeekdays = const [1, 2, 3, 4, 5, 6, 7],
  bool twoLevels = false,
  FakeReservationRepository? repo,
  FakeFloorPlanRepository? floorPlans,
  Clock? clock,
  // #1183 — a test that is ABOUT the sideways layout starts there.
  Size size = const Size(800, 1400),
  double pixelRatio = 1.0,
  void Function(FakeWorkspaceRepository)? configureWorkspace,
}) async {
  // Portrait viewport: these tests exercise the hub's feature behaviour,
  // not the landscape split (which is covered separately). The 800×600
  // default is landscape and would engage the side-panel layout.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  final plans = (floorPlans ?? FakeFloorPlanRepository())..seedSmallPlan();
  if (twoLevels) addSecondLevel(plans);
  final reservations = (repo ?? FakeReservationRepository())
    ..reservations.addAll(seed);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..openWeekdays['ws-1'] = openWeekdays;
  if (granularity != null) {
    workspace.bookingGranularities['ws-1'] = granularity;
  }
  configureWorkspace?.call(workspace);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        reservations: reservations,
        workspace: workspace,
        clock: clock,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  // #1246 — by TYPE, not by the English tooltip: this helper is
  // reused by the locale sweep, where 'Reserve' is 'Reservieren'.
  await tester.tap(find.byType(ShellCenterButton));
  await tester.pumpAndSettle();
  return reservations;
}

/// Centre of seat 'A1' on the hub's canvas (footprint (2,2)..(8,6)).
/// Transform-aware (#278 idiom): the fit scale follows the viewport.
Offset seatCenter(WidgetTester tester) {
  final topLeft = tester.getTopLeft(find.byKey(_canvasKey));
  final scale =
      (tester.getTopRight(find.byKey(_canvasKey)).dx - topLeft.dx) /
      (PlanCanvasMetrics.cells * PlanCanvasMetrics.cellSize);
  return topLeft +
      const Offset(
            5 * PlanCanvasMetrics.cellSize,
            4 * PlanCanvasMetrics.cellSize,
          ) *
          scale;
}

/// Selects [day] through the hub's date chip + calendar dialog (the
/// 7-day pill strip is gone — UX pass). Handles a month rollover with
/// the picker's next-month chevron.
Future<void> pickHubDate(WidgetTester tester, DateTime day) async {
  await tester.tap(find.byKey(const ValueKey('reserve-date-button')));
  await tester.pumpAndSettle();
  final now = kTestNow;
  if (day.month != now.month || day.year != now.year) {
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('${day.day}').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// A reservation on the seeded seat covering [day] [startHour]–[endHour].
Reservation reservationOn(
  DateTime day, {
  required String id,
  String memberId = 'member-1',
  int startHour = 9,
  int endHour = 11,
}) {
  return Reservation(
    id: id,
    workspaceId: 'ws-1',
    seatId: 'seat-4',
    memberId: memberId,
    startsAt: DateTime(day.year, day.month, day.day, startHour),
    endsAt: DateTime(day.year, day.month, day.day, endHour),
    status: ReservationStatus.reserved,
  );
}

const _canvasKey = ValueKey('reserve-plan-canvas');
