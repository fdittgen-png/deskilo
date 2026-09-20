// SPDX-License-Identifier: 0BSD
//
// #1234 — cancel and reschedule, as decisions rather than as a bottom
// sheet.
//
// Before this, none of these had a test at all: `reservation_detail_sheet`
// appears in no test file, and `updateTimes` was exercised only directly
// against the fake. The cancel branch travelled as the strings `'single'`
// and `'following'`, so the only way to reach it was to pump the sheet,
// tap a tile and read what it popped.
//
// The case that matters most here is the last group. #1394: converting a
// booking to a repeat used to be `cancel` then `createSeries`, and when
// no date could be booked `createSeries` returned NORMALLY with an empty
// `booked` — so the client's catch never fired and the member lost the
// booking silently. `convert_to_series` (0224) makes it one transaction
// that refuses, and the fake mirrors that rule.
import 'package:deskilo/features/reservations/application/change_reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_reservation_repository.dart';
import '../../../helpers/test_clock.dart';

const _seat = 'seat-4';
const _me = 'member-1';

/// A Monday inside the fake's world, so weekday patterns behave.
DateTime _monday([int addDays = 0]) {
  var d = kTestNow;
  while (d.weekday != DateTime.monday) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day + addDays, 9);
}

Reservation _mine({
  String id = 'res-mine',
  String? seriesId,
  ReservationStatus status = ReservationStatus.reserved,
  DateTime? startsAt,
}) {
  final start = startsAt ?? _monday();
  return Reservation(
    id: id,
    workspaceId: 'ws-1',
    seatId: _seat,
    memberId: _me,
    startsAt: start,
    endsAt: start.add(const Duration(hours: 4)),
    status: status,
    seriesId: seriesId,
  );
}

void main() {
  late FakeReservationRepository repo;

  setUp(() => repo = FakeReservationRepository());

  group('cancel', () {
    test('a lone booking cancels itself', () async {
      final r = _mine();
      repo.reservations.add(r);

      final outcome = await cancelReservation(repo, r,
          scope: CancelScope.thisOne);

      expect(outcome, isA<CancelledOne>());
      expect(repo.reservations.single.status, ReservationStatus.cancelled);
    });

    test('one occurrence of a repeat leaves the others alone', () async {
      final first = _mine(id: 'res-1', seriesId: 's-1');
      final later = _mine(
          id: 'res-2', seriesId: 's-1', startsAt: _monday(7));
      repo.reservations.addAll([first, later]);

      await cancelReservation(repo, first, scope: CancelScope.thisOne);

      expect(
        repo.reservations.firstWhere((r) => r.id == 'res-2').status,
        ReservationStatus.reserved,
        reason: 'cancelling one occurrence is not cancelling the repeat',
      );
    });

    test('this and following cancels the tail, and says how many',
        () async {
      final first = _mine(id: 'res-1', seriesId: 's-1');
      repo.reservations.addAll([
        first,
        _mine(id: 'res-2', seriesId: 's-1', startsAt: _monday(7)),
        _mine(id: 'res-3', seriesId: 's-1', startsAt: _monday(14)),
      ]);

      final outcome = await cancelReservation(repo, first,
          scope: CancelScope.thisAndFollowing);

      expect(outcome, isA<CancelledFollowing>());
      expect((outcome as CancelledFollowing).count, 3);
      expect(
        repo.reservations.every(
            (r) => r.status == ReservationStatus.cancelled),
        isTrue,
      );
    });

    test('an EARLIER occurrence is not part of "this and following"',
        () async {
      // The tail is defined by the date, not by the series membership —
      // cancelSeries takes `from:`.
      final past = _mine(
          id: 'res-0', seriesId: 's-1', startsAt: _monday(-7));
      final from = _mine(id: 'res-1', seriesId: 's-1');
      repo.reservations.addAll([past, from]);

      await cancelReservation(repo, from,
          scope: CancelScope.thisAndFollowing);

      expect(
        repo.reservations.firstWhere((r) => r.id == 'res-0').status,
        ReservationStatus.reserved,
        reason: 'a date before the one they acted on is not "following"',
      );
    });

    test('asking for the tail of a lone booking cancels that booking',
        () async {
      // "This and the following" of a set of one is that one. It cannot
      // reach cancelSeries, which would throw on a null series.
      final r = _mine();
      repo.reservations.add(r);

      final outcome = await cancelReservation(repo, r,
          scope: CancelScope.thisAndFollowing);

      expect(outcome, isA<CancelledOne>());
      expect(repo.reservations.single.status, ReservationStatus.cancelled);
    });
  });

  group('reschedule', () {
    test('a new window moves the booking and keeps its identity',
        () async {
      final r = _mine();
      repo.reservations.add(r);
      final start = _monday(1);

      final outcome = await rescheduleReservation(
        repo,
        r,
        start: start,
        end: start.add(const Duration(hours: 3)),
      );

      expect(outcome, isA<Moved>());
      expect(repo.reservations.single.id, 'res-mine',
          reason: 'moved, not re-created');
      expect(repo.reservations.single.startsAt, start);
    });

    test('an end change keeps the start, because a running booking may '
        'not move it', () async {
      final r = _mine();
      repo.reservations.add(r);

      final outcome = await changeReservationEnd(
        repo,
        r,
        end: r.endsAt.add(const Duration(hours: 1)),
      );

      expect(outcome.start, r.startsAt);
      expect(repo.reservations.single.startsAt, r.startsAt);
      expect(repo.reservations.single.endsAt,
          r.endsAt.add(const Duration(hours: 1)));
    });

    test('a pattern without an end date is refused before any write',
        () async {
      final r = _mine();
      repo.reservations.add(r);

      expect(
        () => rescheduleReservation(repo, r,
            start: r.startsAt,
            end: r.endsAt,
            pattern: SeriesPattern.weekly),
        throwsA(isA<ArgumentError>()),
      );
      expect(repo.reservations.single.status, ReservationStatus.reserved);
    });
  });

  group('becoming a repeat (#1394)', () {
    test('a conversion whose dates are free books them and cancels the '
        'original', () async {
      final r = _mine();
      repo.reservations.add(r);

      final outcome = await rescheduleReservation(
        repo,
        r,
        start: r.startsAt,
        end: r.endsAt,
        pattern: SeriesPattern.weekly,
        until: r.startsAt.add(const Duration(days: 14)),
      );

      expect(outcome, isA<BecameSeries>());
      expect((outcome as BecameSeries).result.booked, isNotEmpty);
      expect(
        repo.reservations.firstWhere((x) => x.id == 'res-mine').status,
        ReservationStatus.cancelled,
        reason: 'the original gives way to the repeat, in one transaction',
      );
    });

    test('a conversion that can book NOTHING throws and leaves the '
        'booking exactly as it was', () async {
      // The #1394 case, and the reason `convert_to_series` exists. The
      // seat is taken by somebody else on every date the repeat wants,
      // so create_series skips them all and books none.
      final r = _mine();
      repo.reservations.add(r);
      for (var week = 0; week < 3; week++) {
        repo.reservations.add(Reservation(
          id: 'theirs-$week',
          workspaceId: 'ws-1',
          seatId: _seat,
          memberId: 'member-2',
          startsAt: r.startsAt.add(Duration(days: 7 * week)),
          endsAt: r.endsAt.add(Duration(days: 7 * week)),
          status: ReservationStatus.reserved,
        ));
      }

      await expectLater(
        rescheduleReservation(
          repo,
          r,
          start: r.startsAt,
          end: r.endsAt,
          pattern: SeriesPattern.weekly,
          until: r.startsAt.add(const Duration(days: 14)),
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('your booking is unchanged'))),
      );

      expect(
        repo.reservations.firstWhere((x) => x.id == 'res-mine').status,
        ReservationStatus.reserved,
        reason: 'THE assertion: before 0224 the cancel had already '
            'happened and no exception was thrown at all, so the member '
            'lost the booking and was shown a success',
      );
      expect(
        repo.reservations.where((x) => x.seriesId != null),
        isEmpty,
        reason: 'and no half-made series survives the refusal',
      );
    });

    test('a booking already in a repeat cannot become one again',
        () async {
      final r = _mine(seriesId: 's-1');
      repo.reservations.add(r);

      await expectLater(
        rescheduleReservation(repo, r,
            start: r.startsAt,
            end: r.endsAt,
            pattern: SeriesPattern.weekly,
            until: r.startsAt.add(const Duration(days: 14))),
        throwsA(isA<StateError>()),
      );
      expect(repo.reservations.single.status, ReservationStatus.reserved);
    });

    test('the repeat is built from the CHOSEN window, not the stored one '
        '(#1562)', () async {
      // Every case above passes the reservation's OWN start and end, so
      // a command that drops both arguments still passes them all. This
      // one asks for a different window — 14:00–16:00 instead of
      // 09:00–13:00 — which is what the sheet does when the member edits
      // the times and picks a repeat in the same gesture.
      final r = _mine();
      repo.reservations.add(r);
      final newStart = DateTime(
          r.startsAt.year, r.startsAt.month, r.startsAt.day, 14);
      final newEnd = newStart.add(const Duration(hours: 2));

      final outcome = await rescheduleReservation(
        repo,
        r,
        start: newStart,
        end: newEnd,
        pattern: SeriesPattern.weekly,
        until: newStart.add(const Duration(days: 14)),
      );

      expect(outcome, isA<BecameSeries>());
      final made = repo.reservations
          .where((x) => x.seriesId != null)
          .toList(growable: false);
      expect(made, hasLength(3));
      for (var week = 0; week < made.length; week++) {
        expect(made[week].startsAt,
            newStart.add(Duration(days: 7 * week)),
            reason: 'occurrence $week starts at the chosen 14:00, not at '
                'the stored 09:00');
        expect(made[week].endsAt, newEnd.add(Duration(days: 7 * week)),
            reason: 'and keeps the chosen two-hour duration');
      }
    });

    test('the chosen window decides the conflicts, so a date busy only at '
        'the OLD time is still booked (#1562)', () async {
      // The other half of the defect: the skip report answered for the
      // stored window. Somebody else holds the seat 09:00–13:00 on every
      // date the repeat wants; 14:00–16:00 is free on all of them.
      final r = _mine();
      repo.reservations.add(r);
      for (var week = 0; week < 3; week++) {
        repo.reservations.add(Reservation(
          id: 'theirs-$week',
          workspaceId: 'ws-1',
          seatId: _seat,
          memberId: 'member-2',
          startsAt: r.startsAt.add(Duration(days: 7 * week)),
          endsAt: r.endsAt.add(Duration(days: 7 * week)),
          status: ReservationStatus.reserved,
        ));
      }
      final newStart = DateTime(
          r.startsAt.year, r.startsAt.month, r.startsAt.day, 14);

      final outcome = await rescheduleReservation(
        repo,
        r,
        start: newStart,
        end: newStart.add(const Duration(hours: 2)),
        pattern: SeriesPattern.weekly,
        until: newStart.add(const Duration(days: 14)),
      ) as BecameSeries;

      expect(outcome.result.skipped, isEmpty,
          reason: 'nothing conflicts at the requested time');
      expect(outcome.result.booked, hasLength(3));
    });
  });
}
