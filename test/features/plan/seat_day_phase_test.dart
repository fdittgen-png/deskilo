// SPDX-License-Identifier: 0BSD
//
// #575: the plan answers "did/does/will anything happen on this seat
// TODAY" at a glance — the canvas painter rings the seat (grey served /
// green running / half-green ahead) and the list view mirrors it with a
// day dot. One derivation (seatDayPhaseAt) feeds every perspective.
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/seat_state_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_clock.dart';
import 'plan_screen_test.dart' show pumpPlan;

DateTime _at(int hour) =>
    DateTime(kTestNow.year, kTestNow.month, kTestNow.day, hour);

FloorPlanPainter _livePainter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byKey(const ValueKey('reserve-plan-canvas')))
    .painter! as FloorPlanPainter;

void main() {
  testWidgets(
      'the live canvas carries each seat day phase: a completed morning '
      'greys, a booking still ahead rings half-green', (tester) async {
    await pumpPlan(tester, seedReservations: (repo) {
      // The seeded plan's only seat is 'seat-4'; ahead beats behind, so
      // seed the served morning alone first.
      repo.reservations.add(Reservation(
        id: 'res-served',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-2',
        startsAt: _at(8),
        endsAt: _at(9),
        status: ReservationStatus.completed,
      ));
    });

    expect(_livePainter(tester).seatDayPhases['seat-4'], SeatDayPhase.past);
  });

  testWidgets('a booking still ahead today rings half-green (upcoming)',
      (tester) async {
    await pumpPlan(tester, seedReservations: (repo) {
      repo.reservations.add(Reservation(
        id: 'res-ahead',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-2',
        startsAt: _at(15),
        endsAt: _at(16),
        status: ReservationStatus.reserved,
      ));
    });

    expect(
        _livePainter(tester).seatDayPhases['seat-4'], SeatDayPhase.upcoming);
  });

  testWidgets('the list view mirrors the phases with day dots',
      (tester) async {
    await pumpPlan(tester, seedReservations: (repo) {
      repo.reservations.add(Reservation(
        id: 'res-served',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-2',
        startsAt: _at(8),
        endsAt: _at(9),
        status: ReservationStatus.completed,
      ));
    });

    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('seat-day-phase-seat-4')), findsOneWidget);
  });

  testWidgets('a seat with no reservation today carries no dot',
      (tester) async {
    await pumpPlan(tester);

    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('seat-day-phase-seat-4')), findsNothing);
  });
}
