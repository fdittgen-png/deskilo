// SPDX-License-Identifier: 0BSD
//
// Double tap on the plan = whole-space intent (field request: "when
// double tapping on table or room, it must trigger the reservation or
// check in"). A desk cell targets the TABLE, an office cell outside any
// desk targets the ROOM, an in-bounds cell outside every office targets
// the LEVEL — all through the same SpaceSheet the QR scan uses. When
// the viewer already holds the reservation, the sheet checks in to it
// instead of hiding behind a disabled conflict button.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

Future<
    ({
      FakeReservationRepository reservations,
      FakeFloorPlanRepository plans,
      FakeWorkspaceRepository workspace,
    })> pumpHubPlan(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {'levelBooking': true},
  bool granted = true,
  BookingGranularity? granularity,
  void Function(FakeFloorPlanRepository plans)? tunePlan,
  void Function(FakeReservationRepository reservations)? seedReservations,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  // A second office so the plan's used bounds contain an in-bounds GAP
  // (cells 21-23) that hits the LEVEL, plus whole-space pricing on all
  // three rungs.
  plans.offices[0] =
      plans.offices[0].copyWith(rect: const GridRect(x: 0, y: 0, w: 20, h: 20));
  plans.offices.add(plans.offices[0].copyWith(
    id: 'office-far',
    name: 'Back room',
    rect: const GridRect(x: 24, y: 0, w: 4, h: 20),
  ));
  plans.desks[0] = plans.desks[0].copyWith(bookableAsWhole: true);
  plans.offices[0] = plans.offices[0].copyWith(bookableAsWhole: true);
  plans.levels[0] = plans.levels[0].copyWith(bookableAsWhole: true);
  tunePlan?.call(plans);
  final reservations = FakeReservationRepository();
  seedReservations?.call(reservations);
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags)
        ..openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7];
  if (granularity != null) {
    workspace.bookingGranularities['ws-1'] = granularity;
  }
  if (granted) {
    workspace.myMember = workspace.myMember.copyWith(canReserveLevel: true);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        reservations: reservations,
        workspace: workspace,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('reserve-plan-canvas')),
    findsOneWidget,
    reason: 'the hub boots on its plan view',
  );
  return (reservations: reservations, plans: plans, workspace: workspace);
}

/// Transform-aware content position (#278 idiom): the canvas auto-fits,
/// so screen position = origin + cell offset × rendered scale.
Offset cellAt(WidgetTester tester, double x, double y) {
  final finder = find.byKey(const ValueKey('reserve-plan-canvas'));
  final topLeft = tester.getTopLeft(finder);
  final scale = (tester.getTopRight(finder).dx - topLeft.dx) /
      (PlanCanvasMetrics.cells * PlanCanvasMetrics.cellSize);
  return topLeft +
      Offset(x * PlanCanvasMetrics.cellSize, y * PlanCanvasMetrics.cellSize) *
          scale;
}

Future<void> doubleTapCell(WidgetTester tester, double x, double y) async {
  final pos = cellAt(tester, x, y);
  await tester.tapAt(pos);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tapAt(pos);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'double-tapping a TABLE opens its sheet and Reserve books the '
      'whole desk', (tester) async {
    final env = await pumpHubPlan(tester);

    // Desk rect (2,2,12,4); its seat covers x2-8 — cell (12,4) is desk
    // only.
    await doubleTapCell(tester, 12.5, 4.5);

    expect(find.text('Window desk'), findsWidgets);
    // 0065 — Reserve opens the seat sheet's period/repeat picker for
    // the whole space; confirming books the shown window.
    await tester.tap(find.byKey(const ValueKey('space-reserve')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final created = env.reservations.reservations.single;
    expect(created.deskId, env.plans.desks.first.id);
    expect(created.seatId, isNull);
    expect(created.status, ReservationStatus.reserved);
  });

  testWidgets(
      'double-tapping a ROOM outside its desks opens the office sheet '
      'and Check in books the whole office now', (tester) async {
    final env = await pumpHubPlan(tester);

    // Inside office (0,0,20,20) but outside the desk (2,2,12,4).
    await doubleTapCell(tester, 17.5, 15.5);

    expect(find.text('Main room'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('space-checkin')));
    await tester.pumpAndSettle();

    final created = env.reservations.reservations.single;
    expect(created.officeId, env.plans.offices.first.id);
    expect(created.status, ReservationStatus.checkedIn);
  });

  testWidgets(
      'double-tapping the open floor between rooms targets the LEVEL',
      (tester) async {
    await pumpHubPlan(tester);

    // The gap between the two offices (cells 21-23) is inside the used
    // bounds but belongs to no office.
    await doubleTapCell(tester, 22, 10.5);

    expect(find.text('Ground floor'), findsWidgets);
    expect(find.byKey(const ValueKey('space-reserve')), findsOneWidget);
  });

  testWidgets(
      'a table ALREADY RESERVED BY ME double-taps into CHECK IN of that '
      'reservation — not a disabled conflict', (tester) async {
    final now = DateTime.now();
    final env = await pumpHubPlan(
      tester,
      seedReservations: (reservations) => reservations.reservations.add(
        Reservation(
          id: 'res-mine',
          workspaceId: 'ws-1',
          deskId: 'desk-3',
          memberId: 'member-1',
          startsAt: now.subtract(const Duration(hours: 1)),
          endsAt: now.add(const Duration(hours: 8)),
          status: ReservationStatus.reserved,
        ),
      ),
    );
    expect(env.plans.desks.single.id, 'desk-3',
        reason: 'seed sanity: the seeded reservation targets the desk');

    await doubleTapCell(tester, 12.5, 4.5);

    expect(find.byKey(const ValueKey('space-yours')), findsOneWidget);
    expect(find.byKey(const ValueKey('space-reserve')), findsNothing,
        reason: 'my own reservation is not a bookable conflict');
    await tester.tap(find.byKey(const ValueKey('space-checkin-mine')));
    await tester.pumpAndSettle();

    final mine = env.reservations.reservations.single;
    expect(mine.status, ReservationStatus.checkedIn,
        reason: 'double tap on my reserved table checks me in');
  });

  testWidgets(
      'with the whole-space feature OFF a double tap does nothing',
      (tester) async {
    await pumpHubPlan(
      tester,
      featureFlags: const {'levelBooking': false},
      granted: false,
    );

    await doubleTapCell(tester, 12.5, 4.5);

    expect(find.byKey(const ValueKey('space-reserve')), findsNothing);
    expect(find.byKey(const ValueKey('space-checkin')), findsNothing);
    expect(find.text('Window desk'), findsNothing);
  });

  testWidgets(
      'RESERVE offers the CONFIGURED period picker (0065): half-day '
      'chips edit the whole-desk window like a seat booking',
      (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    addTearDown(WorkspaceTime.reset);
    final env = await pumpHubPlan(
      tester,
      granularity: BookingGranularity.halfDay,
    );

    await doubleTapCell(tester, 12.5, 4.5);
    await tester.tap(find.byKey(const ValueKey('space-reserve')));
    await tester.pumpAndSettle();

    // The seat sheet's own picker, for the whole table.
    expect(find.byKey(const ValueKey('booking-am')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-pm')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-day')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-am')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final created = env.reservations.reservations.single;
    expect(created.deskId, env.plans.desks.single.id);
    final now = DateTime.now();
    final expected =
        HalfDayWindows.morning(DateTime(now.year, now.month, now.day));
    expect(created.startsAt.toUtc(), expected.start.toUtc());
    expect(created.endsAt.toUtc(), expected.end.toUtc());
  });

  testWidgets(
      'under FLEXIBLE granularity the whole-space picker shows '
      'From/Until tiles — the picker follows the configuration',
      (tester) async {
    await pumpHubPlan(tester);

    await doubleTapCell(tester, 12.5, 4.5);
    await tester.tap(find.byKey(const ValueKey('space-reserve')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('booking-from-tile')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-until-tile')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-am')), findsNothing);
  });

  testWidgets(
      'REPETITION (0065): a weekly repeat on a ROOM creates a series of '
      'whole-office reservations with the skipped report',
      (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    addTearDown(WorkspaceTime.reset);
    final env = await pumpHubPlan(
      tester,
      granularity: BookingGranularity.halfDay,
    );

    await doubleTapCell(tester, 17.5, 15.5); // office, outside the desk
    await tester.tap(find.byKey(const ValueKey('space-reserve')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-repeat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    // 28-day default horizon, weekly → 5 occurrences, all office-whole.
    final series = env.reservations.reservations
        .where((r) => r.officeId == env.plans.offices.first.id)
        .toList();
    expect(series, hasLength(5));
    expect(series.map((r) => r.seriesId).toSet(), hasLength(1));
    expect(series.every((r) => r.seatId == null), isTrue);
    // The series result dialog reports the booked occurrences.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });
}
