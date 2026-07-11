// SPDX-License-Identifier: MIT
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
  // Browsed window 09:00–12:00 (#184).
  final nine = DateTime.utc(2026, 7, 7, 9);
  final ten = DateTime.utc(2026, 7, 7, 10);
  final eleven = DateTime.utc(2026, 7, 7, 11);
  final noon = DateTime.utc(2026, 7, 7, 12);
  final fourteen = DateTime.utc(2026, 7, 7, 14);

  SeatState stateIn(List<Reservation> reservations, DateTime from, DateTime to,
          {String? me = 'member-1', Seat onSeat = seat}) =>
      seatStateInRange(
        plan: plan,
        seat: onSeat,
        reservations: reservations,
        myMemberId: me,
        from: from,
        to: to,
      );

  group('Reservation.coversRange', () {
    test('overlap in the middle of the window', () {
      expect(reservation(start: ten, end: eleven).coversRange(nine, noon),
          isTrue);
    });

    test('spanning the whole window overlaps', () {
      expect(reservation(start: nine, end: fourteen).coversRange(ten, eleven),
          isTrue);
    });

    test('ending exactly at the window start does NOT overlap', () {
      expect(reservation(start: nine, end: ten).coversRange(ten, noon),
          isFalse);
    });

    test('starting exactly at the window end does NOT overlap', () {
      expect(reservation(start: noon, end: fourteen).coversRange(nine, noon),
          isFalse);
    });

    test('inactive reservations never overlap', () {
      for (final status in [
        ReservationStatus.cancelled,
        ReservationStatus.completed,
        ReservationStatus.released,
      ]) {
        expect(
          reservation(start: ten, end: eleven, status: status)
              .coversRange(nine, noon),
          isFalse,
          reason: '$status',
        );
      }
    });
  });

  group('seatStateInRange', () {
    test('free when nothing overlaps the window', () {
      expect(stateIn(const [], nine, noon), SeatState.free);
      // Ends exactly at the window start → free (end exclusive).
      expect(
        stateIn([reservation(start: nine, end: ten)], ten, noon),
        SeatState.free,
      );
      // Starts exactly at the window end → free.
      expect(
        stateIn([reservation(start: noon, end: fourteen)], nine, noon),
        SeatState.free,
      );
    });

    test('a mid-window reservation makes the seat reserved/occupied', () {
      final r = reservation(start: ten, end: eleven);
      expect(stateIn([r], nine, noon), SeatState.reserved);
      expect(
        stateIn([r.copyWith(status: ReservationStatus.checkedIn)], nine, noon),
        SeatState.occupied,
      );
    });

    test('own overlapping reservation shows as mine', () {
      final r = reservation(start: ten, end: eleven, memberId: 'member-1');
      expect(stateIn([r], nine, noon), SeatState.mine);
    });

    test('an office-as-whole booking covers the seats inside', () {
      final r = reservation(
        seatId: null,
        officeId: 'office-1',
        start: ten,
        end: eleven,
      );
      expect(stateIn([r], nine, noon), SeatState.reserved);
    });

    test('blocked when the maintenance block overlaps the window', () {
      final blocked = seat.copyWith(blockedFrom: ten, blockedTo: eleven);
      expect(stateIn(const [], nine, noon, onSeat: blocked),
          SeatState.blocked);
      // Block ending exactly at the window start → not blocked.
      expect(stateIn(const [], eleven, noon, onSeat: blocked),
          SeatState.free);
      // Block starting exactly at the window end → not blocked.
      expect(stateIn(const [], nine, ten, onSeat: blocked),
          SeatState.free);
      // Partial overlap into the block → blocked.
      expect(
        stateIn(const [], nine, ten.add(const Duration(minutes: 30)),
            onSeat: blocked),
        SeatState.blocked,
      );
    });

    test('open-ended blocks overlap like Seat.isBlockedAt', () {
      // blockedFrom null = since forever.
      final sinceForever = seat.copyWith(blockedTo: ten);
      expect(stateIn(const [], nine, noon, onSeat: sinceForever),
          SeatState.blocked);
      expect(stateIn(const [], ten, noon, onSeat: sinceForever),
          SeatState.free);
      // blockedTo null = forever.
      final forever = seat.copyWith(blockedFrom: eleven);
      expect(stateIn(const [], nine, noon, onSeat: forever),
          SeatState.blocked);
      expect(stateIn(const [], nine, eleven, onSeat: forever),
          SeatState.free);
    });

    test('blocked wins over reservations', () {
      final blocked = seat.copyWith(blockedFrom: nine, blockedTo: noon);
      expect(
        stateIn([reservation(start: ten, end: eleven)], nine, noon,
            onSeat: blocked),
        SeatState.blocked,
      );
    });
  });

  group('reservationOnSeatInRange', () {
    test('returns the overlapping reservation, null otherwise', () {
      final r = reservation(start: ten, end: eleven);
      expect(
        reservationOnSeatInRange(
          plan: plan,
          seat: seat,
          reservations: [r],
          from: nine,
          to: noon,
        )?.id,
        'res-1',
      );
      expect(
        reservationOnSeatInRange(
          plan: plan,
          seat: seat,
          reservations: [r],
          from: eleven,
          to: noon,
        ),
        isNull,
      );
    });
  });
}
