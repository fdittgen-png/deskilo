// SPDX-License-Identifier: 0BSD
//
// Auto check-in/out (#396, migration 0075): with the workspace's
// autoCheckInOut flag on, a reservation nobody touched completes itself
// once its time has passed — checked in at its start, checked out at its
// end. The server enforces this in `sweep_day_end` (invoked lazily before
// reservation reads); the fake mirrors that contract, and these tests pin
// the CLIENT-visible semantics against the fake seam, the same way the
// booking-rules and quota contracts are pinned.

import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

Reservation _at(
  DateTime start,
  DateTime end, {
  String id = 'res-1',
  ReservationStatus status = ReservationStatus.reserved,
  DateTime? checkedInAt,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: 'seat-4',
      memberId: 'member-1',
      startsAt: start,
      endsAt: end,
      status: status,
      checkedInAt: checkedInAt,
    );

void main() {
  final yesterday = kTestNow.subtract(const Duration(days: 1));
  final start = DateTime(yesterday.year, yesterday.month, yesterday.day, 9);
  final end = DateTime(yesterday.year, yesterday.month, yesterday.day, 17);

  test('flag ON: a never-checked-in past reservation completes with both '
      'stamps — checked in at its start, out at its end', () async {
    final repo = FakeReservationRepository()
      ..autoCheckInOut = true
      ..reservations.add(_at(start, end));

    final fetched = await repo.fetchWindow(
      'ws-1',
      from: start.subtract(const Duration(days: 1)),
      to: kTestNow,
    );

    final swept = fetched.single;
    expect(swept.status, ReservationStatus.completed);
    expect(swept.checkedInAt, start,
        reason: 'attended by decree: the booking held the seat from its '
            'own start');
    expect(swept.checkedOutAt, end);
  });

  test('flag ON: a forgotten check-out closes at the reservation END, '
      'not at now — the seat was only theirs until ends_at', () async {
    final repo = FakeReservationRepository()
      ..autoCheckInOut = true
      ..reservations.add(_at(
        start,
        end,
        status: ReservationStatus.checkedIn,
        checkedInAt: start,
      ));

    final fetched = await repo.fetchWindow(
      'ws-1',
      from: start.subtract(const Duration(days: 1)),
      to: kTestNow,
    );

    final swept = fetched.single;
    expect(swept.status, ReservationStatus.completed);
    expect(swept.checkedInAt, start, reason: 'the real check-in survives');
    expect(swept.checkedOutAt, end);
  });

  test('flag ON: a still-running reservation is untouched — the sweep '
      'keys off the reservation\'s own end', () async {
    final running = _at(
      kTestNow.subtract(const Duration(hours: 1)),
      kTestNow.add(const Duration(hours: 1)),
    );
    final repo = FakeReservationRepository()
      ..autoCheckInOut = true
      ..reservations.add(running);

    final fetched = await repo.fetchWindow(
      'ws-1',
      from: kTestNow.subtract(const Duration(days: 1)),
      to: kTestNow.add(const Duration(days: 1)),
    );

    expect(fetched.single.status, ReservationStatus.reserved);
    expect(fetched.single.checkedInAt, isNull);
  });

  test('flag ON: cancelled stays cancelled — the sweep never resurrects '
      'a dead booking into an attended one', () async {
    final repo = FakeReservationRepository()
      ..autoCheckInOut = true
      ..reservations
          .add(_at(start, end, status: ReservationStatus.cancelled));

    final fetched = await repo.fetchWindow(
      'ws-1',
      from: start.subtract(const Duration(days: 1)),
      to: kTestNow,
    );

    expect(fetched.single.status, ReservationStatus.cancelled);
    expect(fetched.single.checkedOutAt, isNull);
  });

  test('flag OFF (the default): nothing moves — rewriting attendance is '
      'an explicit owner decision', () async {
    final repo = FakeReservationRepository()..reservations.add(_at(start, end));

    final fetched = await repo.fetchWindow(
      'ws-1',
      from: start.subtract(const Duration(days: 1)),
      to: kTestNow,
    );

    expect(fetched.single.status, ReservationStatus.reserved);
    expect(fetched.single.checkedInAt, isNull);
  });
}
