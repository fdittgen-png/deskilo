// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/seat_state_logic.dart';
import 'package:flutter_test/flutter_test.dart';

const seat = Seat(
  id: 'seat-1',
  workspaceId: 'ws-1',
  deskId: 'desk-1',
  name: 'A1',
  x: 0,
  y: 0,
  orientation: SeatOrientation.n,
  chair: '',
  amenities: [],
);

const plan = FloorPlan(
  levelId: 'level-1',
  offices: [],
  desks: [
    Desk(
      id: 'desk-1',
      workspaceId: 'ws-1',
      officeId: 'office-1',
      name: '',
      rect: GridRect(x: 0, y: 0, w: 6, h: 4),
    ),
  ],
  seats: [seat],
);

Reservation reservation({
  String id = 'res-1',
  String? seatId = 'seat-1',
  String? officeId,
  String memberId = 'member-2',
  ReservationStatus status = ReservationStatus.reserved,
  required DateTime start,
  required DateTime end,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: seatId,
      officeId: officeId,
      memberId: memberId,
      startsAt: start,
      endsAt: end,
      status: status,
    );

void main() {
  final noon = DateTime.utc(2026, 7, 7, 12);
  final morning = DateTime.utc(2026, 7, 7, 9);
  final evening = DateTime.utc(2026, 7, 7, 18);

  SeatState stateAt(List<Reservation> reservations, DateTime at,
          {String? me = 'member-1'}) =>
      seatStateAt(
        plan: plan,
        seat: seat,
        reservations: reservations,
        myMemberId: me,
        at: at,
      );

  test('free when nothing covers the instant', () {
    expect(stateAt(const [], noon), SeatState.free);
    expect(
      stateAt([reservation(start: evening, end: evening.add(const Duration(hours: 2)))], noon),
      SeatState.free,
    );
  });

  test('reserved vs occupied depends on check-in', () {
    final r = reservation(start: morning, end: evening);
    expect(stateAt([r], noon), SeatState.reserved);
    expect(
      stateAt([r.copyWith(status: ReservationStatus.checkedIn)], noon),
      SeatState.occupied,
    );
  });

  test('own reservation shows as mine regardless of check-in', () {
    final r = reservation(start: morning, end: evening, memberId: 'member-1');
    expect(stateAt([r], noon), SeatState.mine);
    expect(
      stateAt([r.copyWith(status: ReservationStatus.checkedIn)], noon),
      SeatState.mine,
    );
  });

  test('cancelled/completed/released reservations do not block', () {
    for (final status in [
      ReservationStatus.cancelled,
      ReservationStatus.completed,
      ReservationStatus.released,
    ]) {
      final r =
          reservation(start: morning, end: evening, status: status);
      expect(stateAt([r], noon), SeatState.free, reason: '$status');
    }
  });

  test('an office-as-whole booking covers the seats inside', () {
    final r = reservation(
      seatId: null,
      officeId: 'office-1',
      start: morning,
      end: evening,
    );
    expect(stateAt([r], noon), SeatState.reserved);
  });

  test('blocked wins over reservations', () {
    final blockedSeat = seat.copyWith(
      blockedFrom: morning,
      blockedTo: evening,
    );
    final state = seatStateAt(
      plan: plan,
      seat: blockedSeat,
      reservations: [reservation(start: morning, end: evening)],
      myMemberId: 'member-1',
      at: noon,
    );
    expect(state, SeatState.blocked);
  });

  test('boundary semantics: start inclusive, end exclusive', () {
    final r = reservation(start: morning, end: noon);
    expect(stateAt([r], morning), SeatState.reserved);
    expect(stateAt([r], noon), SeatState.free);
  });

  test('nextReservationOnSeat finds the earliest future active booking', () {
    final later = reservation(
      id: 'res-later',
      start: evening,
      end: evening.add(const Duration(hours: 1)),
    );
    final sooner = reservation(
      id: 'res-sooner',
      start: noon.add(const Duration(hours: 1)),
      end: noon.add(const Duration(hours: 2)),
    );
    final next = nextReservationOnSeat(
      seat: seat,
      reservations: [later, sooner],
      at: noon,
    );
    expect(next?.id, 'res-sooner');
  });
}
