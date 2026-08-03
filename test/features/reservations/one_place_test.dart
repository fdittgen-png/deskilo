// SPDX-License-Identifier: 0BSD
//
// One place at a time (#412, migration 0079): a member cannot hold two
// ACTIVE reservations overlapping in time — the field bug was a walk-up
// check-in on a second seat while still checked in on the first. The
// 0079 BEFORE INSERT trigger refuses with a pinned substring; check-in
// refuses while checked in elsewhere on a RUNNING reservation and
// auto-completes stale ones at their own end. The fake mirrors all of
// it; bookingErrorText maps the substrings.

import 'package:deskilo/features/reservations/domain/booking_error_text.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

Reservation _mine({
  String id = 'res-mine',
  String seatId = 'seat-1',
  DateTime? start,
  DateTime? end,
  ReservationStatus status = ReservationStatus.checkedIn,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: seatId,
      memberId: 'member-1',
      startsAt: start ?? kTestNow.subtract(const Duration(hours: 1)),
      endsAt: end ?? kTestNow.add(const Duration(hours: 2)),
      status: status,
      checkedInAt:
          status == ReservationStatus.checkedIn ? kTestNow : null,
    );

Matcher _refuses(String substring) => throwsA(isA<PostgrestException>()
    .having((e) => e.message, 'message', contains(substring)));

void main() {
  test('the field bug: a second walk-up while checked in refuses', () async {
    final repo = FakeReservationRepository()..reservations.add(_mine());
    await expectLater(
      repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-2',
        startsAt: kTestNow,
        endsAt: kTestNow.add(const Duration(hours: 2)),
        checkIn: true,
      ),
      _refuses('you already have a reservation in that period'),
    );
    expect(repo.reservations, hasLength(1));
  });

  test('an overlapping plain reservation refuses too — reserved counts '
      'as occupied for the member', () async {
    final repo = FakeReservationRepository()
      ..reservations.add(_mine(status: ReservationStatus.reserved));
    await expectLater(
      repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-2',
        startsAt: kTestNow.add(const Duration(hours: 1)),
        endsAt: kTestNow.add(const Duration(hours: 3)),
      ),
      _refuses('you already have a reservation in that period'),
    );
  });

  test('a non-overlapping later reservation is fine', () async {
    final repo = FakeReservationRepository()..reservations.add(_mine());
    await repo.create(
      workspaceId: 'ws-1',
      seatId: 'seat-2',
      startsAt: kTestNow.add(const Duration(hours: 3)),
      endsAt: kTestNow.add(const Duration(hours: 5)),
    );
    expect(repo.reservations, hasLength(2));
  });

  test('check-in refuses while checked in elsewhere on a RUNNING '
      'reservation', () async {
    final repo = FakeReservationRepository()
      ..reservations.add(_mine())
      ..reservations.add(_mine(
        id: 'res-next',
        seatId: 'seat-2',
        start: kTestNow.subtract(const Duration(minutes: 5)),
        end: kTestNow.add(const Duration(hours: 4)),
        status: ReservationStatus.reserved,
      ));
    await expectLater(
      repo.checkIn('res-next'),
      _refuses('already checked in elsewhere'),
    );
  });

  test('a STALE check-in completes itself at its own end and the new '
      'check-in goes through', () async {
    final repo = FakeReservationRepository()
      ..reservations.add(_mine(
        start: kTestNow.subtract(const Duration(hours: 4)),
        end: kTestNow.subtract(const Duration(hours: 1)),
      ))
      ..reservations.add(_mine(
        id: 'res-next',
        seatId: 'seat-2',
        start: kTestNow,
        end: kTestNow.add(const Duration(hours: 4)),
        status: ReservationStatus.reserved,
      ));
    await repo.checkIn('res-next');
    final stale = repo.reservations.firstWhere((r) => r.id == 'res-mine');
    expect(stale.status, ReservationStatus.completed);
    expect(stale.checkedOutAt, stale.endsAt,
        reason: 'the seat was only theirs until its own end (0075 idiom)');
    expect(repo.reservations.firstWhere((r) => r.id == 'res-next').status,
        ReservationStatus.checkedIn);
  });

  test('series: member-busy dates land in the skip report like any '
      'conflict', () async {
    final repo = FakeReservationRepository()
      ..reservations.add(_mine(status: ReservationStatus.reserved));
    final result = await repo.createSeries(
      workspaceId: 'ws-1',
      seatId: 'seat-2',
      firstStart: kTestNow.subtract(const Duration(minutes: 30)),
      firstEnd: kTestNow.add(const Duration(hours: 1)),
      pattern: SeriesPattern.daily,
      until: kTestNow.add(const Duration(days: 2)),
    );
    expect(result.skipped, hasLength(1),
        reason: 'day one overlaps my existing reservation');
    expect(result.booked, hasLength(2));
  });

  test('booking for another member refuses when THAT member is busy',
      () async {
    final repo = FakeReservationRepository()
      ..reservations.add(Reservation(
        id: 'res-ana',
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        memberId: 'member-2',
        startsAt: kTestNow,
        endsAt: kTestNow.add(const Duration(hours: 2)),
        status: ReservationStatus.reserved,
      ));
    await expectLater(
      repo.createFor(
        workspaceId: 'ws-1',
        subjectMemberId: 'member-2',
        seatId: 'seat-3',
        startsAt: kTestNow.add(const Duration(hours: 1)),
        endsAt: kTestNow.add(const Duration(hours: 3)),
      ),
      _refuses('you already have a reservation in that period'),
    );
  });

  group('bookingErrorText maps the new pinned substrings', () {
    String map(String message) => bookingErrorText(
        null, PostgrestException(message: message), 'fallback');

    test('one place', () {
      expect(map('you already have a reservation in that period'),
          contains('one place at a time'));
      expect(map('already checked in elsewhere'), contains('check out'));
    });

    test('whole-space setup refusals stop being generic (#412)', () {
      expect(map('desk not bookable as a whole'), contains('editor'));
      expect(map('office not bookable as a whole'), contains('editor'));
      expect(map('level not bookable as a whole'), contains('editor'));
      expect(map('level booking is not enabled'), contains('Features'));
    });
  });
}
