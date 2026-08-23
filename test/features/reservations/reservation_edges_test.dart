// SPDX-License-Identifier: 0BSD
//
// #600 (migration 0116) — the reservation/check-in edges a live-RPC
// test matrix surfaced. A check-out BEFORE the reserved slot's start
// (possible since 0113's early same-day check-in) records the REAL
// presence instead of dying on the start<end constraint; a walk-up
// check-in must start on the workspace-local TODAY; fully-past bookings
// are refused unless the owner switched allow_past_bookings on; and the
// client presence gate mirrors the server's day-based same-day rule
// instead of the flat 15-minute leeway.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/test_clock.dart';

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(kTestNow.year, kTestNow.month, kTestNow.day, hour, minute);

Reservation _row({
  ReservationStatus status = ReservationStatus.reserved,
  required DateTime start,
  required DateTime end,
}) =>
    Reservation(
      id: 'res-1',
      workspaceId: 'ws-1',
      seatId: 'seat-1',
      memberId: 'member-1',
      startsAt: start,
      endsAt: end,
      status: status,
    );

void main() {
  tearDown(WorkspaceTime.reset);

  group('check-out before the slot start (#600)', () {
    test('an early same-day check-in checked out before the slot begins '
        'completes with the REAL presence window, never end <= start',
        () async {
      final repo = FakeReservationRepository()
        ..granularity = BookingGranularity.halfDay;
      // Afternoon slot 12:00-17:00, checked in early at 10:00 (0113
      // same-day presence), checked out at 10:00 (kTestNow) too.
      final id = await repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _at(12),
        endsAt: _at(17),
      );
      repo.reservations.last = repo.reservations.last.copyWith(
        status: ReservationStatus.checkedIn,
        checkedInAt: kTestNow,
      );
      await repo.checkOut(id);
      final r = repo.reservations.last;
      expect(r.status, ReservationStatus.completed);
      expect(r.endsAt.isAfter(r.startsAt), isTrue,
          reason: 'the completed row must stay a valid forward window');
      expect(r.startsAt, kTestNow,
          reason: 'presence began at the early check-in, not the slot');
    });

    test('a normal early check-out inside the slot still truncates to '
        'now and keeps its start', () async {
      final repo = FakeReservationRepository()
        ..granularity = BookingGranularity.halfDay;
      final id = await repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _at(10),
        endsAt: _at(12),
        checkIn: true,
      );
      await repo.checkOut(id);
      final r = repo.reservations.last;
      expect(r.status, ReservationStatus.completed);
      expect(r.startsAt, _at(8),
          reason: '0113 snapped the walk-up back to the slot start');
      expect(r.endsAt, kTestNow, reason: 'early check-out truncates');
    });
  });

  group('walk-up check-in is same-day only (#600)', () {
    test('a walk-up check-in for TOMORROW is refused on every '
        'granularity', () async {
      for (final granularity in [
        BookingGranularity.minutes5,
        BookingGranularity.halfDay,
      ]) {
        final repo = FakeReservationRepository()..granularity = granularity;
        final tomorrow = kTestNow.add(const Duration(days: 1));
        await expectLater(
          repo.create(
            workspaceId: 'ws-1',
            seatId: 'seat-1',
            startsAt: DateTime(
                tomorrow.year, tomorrow.month, tomorrow.day, 10),
            endsAt: DateTime(
                tomorrow.year, tomorrow.month, tomorrow.day, 12),
            checkIn: true,
          ),
          throwsA(predicate((e) =>
              e.toString().contains('must start today'))),
        );
      }
    });
  });

  group('fully-past bookings (#600)', () {
    test('refused by default, allowed once the owner switches '
        'allow_past_bookings on', () async {
      final repo = FakeReservationRepository()
        ..granularity = BookingGranularity.halfDay;
      final yesterday = kTestNow.subtract(const Duration(days: 1));
      DateTime y(int hour) =>
          DateTime(yesterday.year, yesterday.month, yesterday.day, hour);
      await expectLater(
        repo.create(
          workspaceId: 'ws-1',
          seatId: 'seat-1',
          startsAt: y(8),
          endsAt: y(12),
        ),
        throwsA(predicate(
            (e) => e.toString().contains('lies entirely in the past'))),
      );
      repo.allowPastBookings = true;
      final id = await repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: y(8),
        endsAt: y(12),
      );
      expect(id, isNotEmpty);
    });
  });

  group('client presence gate mirrors 0113 (#600)', () {
    test('day-based: any same-workspace-day arrival opens the window — '
        'the afternoon slot is check-in-able at 10:00', () {
      final r = _row(start: _at(12), end: _at(17));
      expect(
        r.checkInWindowOpen(kTestNow,
            granularity: BookingGranularity.halfDay),
        isTrue,
      );
      // Without the granularity the historical flat leeway still rules.
      expect(r.checkInWindowOpen(kTestNow), isFalse);
    });

    test('a reservation on ANOTHER day stays closed even under the '
        'day-based rule', () {
      final tomorrow = kTestNow.add(const Duration(days: 1));
      final r = _row(
        start: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8),
        end: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12),
      );
      expect(
        r.checkInWindowOpen(kTestNow,
            granularity: BookingGranularity.halfDay),
        isFalse,
      );
    });

    test('minute grids widen the leeway to one grid step', () {
      final r = _row(start: _at(10, 50), end: _at(12));
      // 50 minutes ahead: outside the flat 15-minute leeway...
      expect(r.checkInWindowOpen(kTestNow), isFalse);
      // ...but inside a 60-minute grid step.
      expect(
        r.checkInWindowOpen(kTestNow,
            granularity: BookingGranularity.minutes60),
        isTrue,
      );
    });

    test('after the end the window is closed under every rule', () {
      final r = _row(start: _at(8), end: _at(9, 30));
      expect(
        r.checkInWindowOpen(kTestNow,
            granularity: BookingGranularity.halfDay),
        isFalse,
        reason: 'check-in after the reservation ended must stay refused',
      );
    });
  });
}
