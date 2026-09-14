// SPDX-License-Identifier: 0BSD
//
// #1234 — the point of the application layer, demonstrated.
//
// Every one of these ran through a widget before: to find out whether
// booking for somebody else creates a confirmation request rather than a
// reservation, you had to pump the Reserve hub, open a bottom sheet,
// pick a member and tap a button. The decision was in a 740-line widget
// method, so the only way to reach it was through the screen.
//
// It is a function now. No `pumpWidget`, no `BuildContext`, no bottom
// sheet — and these run in milliseconds.
import 'package:deskilo/features/reservations/application/book_seat.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_reservation_repository.dart';
import '../../../helpers/test_clock.dart';

final _start = DateTime.utc(2026, 9, 14, 9);
final _end = DateTime.utc(2026, 9, 14, 13);

BookingRequest request({
  String? forMemberId,
  SeriesPattern? pattern,
  DateTime? until,
  bool checkIn = false,
}) =>
    (
      workspaceId: 'ws-1',
      seatId: 'seat-4',
      start: _start,
      end: _end,
      checkIn: checkIn,
      forMemberId: forMemberId,
      pattern: pattern,
      until: until,
    );

void main() {
  late FakeReservationRepository repo;

  setUp(() => repo = FakeReservationRepository());

  test('a booking for myself is a reservation', () async {
    final outcome = await bookSeat(repo, request(), myMemberId: 'member-1');

    expect(outcome, isA<Booked>());
    expect((outcome as Booked).checkedIn, isFalse);
    expect(repo.reservations, hasLength(1));
    expect(repo.reservations.single.seatId, 'seat-4');
  });

  test('a walk-up reports that it CHECKED IN, because telling somebody '
      'standing at a desk that they merely reserved it is the '
      'confirmation lying (#687)', () async {
    // A walk-up must start TODAY, and "today" is the fake's clock rather
    // than the wall clock — the fake enforces the same rule the server
    // does, on `kTestNow`.
    final now = kTestNow;
    final outcome = await bookSeat(
      repo,
      (
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        start: now,
        end: now.add(const Duration(hours: 2)),
        checkIn: true,
        forMemberId: null,
        pattern: null,
        until: null,
      ),
      myMemberId: 'member-1',
    );

    expect((outcome as Booked).checkedIn, isTrue);
  });

  test('booking for somebody ELSE is a confirmation request — never a '
      'check-in, because they have agreed to nothing yet (#106)', () async {
    final outcome = await bookSeat(
      repo,
      request(forMemberId: 'member-2', checkIn: true),
      myMemberId: 'member-1',
    );

    expect(outcome, isA<SentForConfirmation>());
    expect((outcome as SentForConfirmation).subjectMemberId, 'member-2');
    expect(repo.bookedForOthers, hasLength(1),
        reason: 'it went through createFor, not create');
    expect(repo.reservations.single.checkedInAt, isNull,
        reason: 'the subject is not standing at the desk; checking them in '
            'would be the app deciding on their behalf');
  });

  test('naming MYSELF in the picker is still an ordinary booking — the '
      'branch is "somebody else", not "somebody was named"', () async {
    final outcome = await bookSeat(
      repo,
      request(forMemberId: 'member-1'),
      myMemberId: 'member-1',
    );

    expect(outcome, isA<Booked>());
    expect(repo.bookedForOthers, isEmpty);
  });

  test('a pattern makes it a series, and the partial result comes back '
      'for the caller to show', () async {
    final outcome = await bookSeat(
      repo,
      request(
        pattern: SeriesPattern.weekly,
        until: DateTime.utc(2026, 10, 14),
      ),
      myMemberId: 'member-1',
    );

    expect(outcome, isA<SeriesBooked>());
    expect((outcome as SeriesBooked).result, isA<SeriesResult>());
  });

  test('a series booked FOR somebody else is a confirmation request: '
      'whose booking it is decides first, and repeating second', () async {
    final outcome = await bookSeat(
      repo,
      request(
        forMemberId: 'member-2',
        pattern: SeriesPattern.daily,
        until: DateTime.utc(2026, 10, 14),
      ),
      myMemberId: 'member-1',
    );

    expect(outcome, isA<SentForConfirmation>(),
        reason: 'a repeat somebody has not agreed to is still something '
            'they have not agreed to');
  });

  test('the server\'s own words reach the caller: the command does not '
      'catch (#1030)', () async {
    // The fake refuses exactly as the server does — a walk-up check-in
    // must start today — and that refusal must arrive at the caller
    // untouched. Swallowing it here to return a tidier type would throw
    // away the sentence somebody standing at a desk needs.
    await expectLater(
      bookSeat(repo, request(checkIn: true), myMemberId: 'member-1'),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message',
            contains('walk-up check-in must start today')),
      ),
    );
  });
}
