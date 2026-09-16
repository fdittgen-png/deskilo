// SPDX-License-Identifier: 0BSD
//
// #1234 — the same decisions as `already_checked_in_test.dart`, without
// the application.
//
// That test is 219 lines and every case boots `DeskiloApp`, taps the
// scan button, types a space code, submits, waits for the sheet and
// inspects widget keys — to establish which of four branches a
// five-comparison decision takes. It stays: it proves the SHEET renders
// the refusal, which is a real and separate claim.
//
// This proves the decision itself, as a function, with a fake repository
// and no widget tree. ADR 0024 is the argument; this is the second proof
// after `book_seat_test.dart`.
import 'package:deskilo/features/reservations/application/act_on_space.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/space_act.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_reservation_repository.dart';
import '../../../helpers/test_clock.dart';

const _seat = 'seat-4';
const _me = 'member-1';

Reservation _mine({
  required ReservationStatus status,
  DateTime? startsAt,
  DateTime? endsAt,
  DateTime? checkedInAt,
  String id = 'res-mine',
  String seatId = _seat,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: seatId,
      memberId: _me,
      startsAt: startsAt ?? kTestNow.subtract(const Duration(hours: 1)),
      endsAt: endsAt ?? kTestNow.add(const Duration(hours: 3)),
      status: status,
      checkedInAt: checkedInAt,
    );

SpaceActRequest _request(
  SpaceAction action, {
  required List<Reservation> day,
  DateTime? start,
  DateTime? end,
  bool checkInNow = false,
}) =>
    (
      workspaceId: 'ws-1',
      seatId: _seat,
      choice: (
        action: action,
        start: start ?? kTestNow,
        end: end ?? kTestNow.add(const Duration(hours: 2)),
        checkInNow: checkInNow,
      ),
      dayReservations: day,
      myMemberId: _me,
      now: kTestNow,
      granularity: BookingGranularity.flexible,
    );

void main() {
  late FakeReservationRepository repo;

  setUp(() => repo = FakeReservationRepository());

  group('check in', () {
    test('my reservation here is checked into, never re-created', () async {
      final mine = _mine(
        status: ReservationStatus.reserved,
        startsAt: kTestNow.subtract(const Duration(minutes: 10)),
      );
      repo.reservations.add(mine);

      final outcome = await actOnSpace(repo, _request(
        SpaceAction.checkIn,
        day: [mine],
      ));

      expect(outcome, isA<CheckedIntoExisting>());
      expect((outcome as CheckedIntoExisting).reservationId, 'res-mine');
      expect(repo.createCalls, 0,
          reason: 'it checks into the EXISTING reservation');
      expect(
        repo.reservations.single.status,
        ReservationStatus.checkedIn,
      );
    });

    test('#1135 — already checked in HERE refuses without asking the '
        'server, because the request cannot succeed', () async {
      final live = _mine(
        status: ReservationStatus.checkedIn,
        checkedInAt: kTestNow.subtract(const Duration(hours: 1)),
      );
      repo.reservations.add(live);

      final outcome = await actOnSpace(repo, _request(
        SpaceAction.checkIn,
        day: [live],
      ));

      expect(outcome, isA<AlreadyCheckedInHere>());
      // The assertion that matters. Counting rows cannot tell "the app
      // never asked" from "the app asked and the server said no", and
      // the field trace was five impossible creates in 2.5 seconds.
      expect(repo.createCalls, 0,
          reason: 'a request that cannot succeed must never leave the '
              'device');
    });

    test('a LATER window on the same seat is not refused — the rule is '
        'overlap, and the sheet must not be stricter than the server',
        () async {
      final live = _mine(
        status: ReservationStatus.checkedIn,
        endsAt: kTestNow.add(const Duration(minutes: 90)),
        checkedInAt: kTestNow.subtract(const Duration(hours: 1)),
      );
      repo.reservations.add(live);
      final afternoon = kTestNow.add(const Duration(hours: 3));

      final outcome = await actOnSpace(repo, _request(
        SpaceAction.checkIn,
        day: [live],
        start: afternoon,
        end: afternoon.add(const Duration(hours: 2)),
      ));

      expect(outcome, isA<WalkedUp>(),
          reason: 'enforce_one_place counts overlaps and nothing else');
      // And it genuinely reached the repository: the fake's
      // `_assertMemberFree` would refuse an OVERLAPPING row of mine at
      // the default allowance of 1, so this passing proves the windows
      // are disjoint rather than proving the guard is absent.
      expect(repo.createCalls, 1);
    });

    test('a free seat walks up — created AND checked in, because '
        'somebody is already sitting there (#687)', () async {
      final outcome = await actOnSpace(repo, _request(
        SpaceAction.checkIn,
        day: const [],
      ));

      expect(outcome, isA<WalkedUp>());
      expect(repo.reservations.single.status, ReservationStatus.checkedIn);
    });

    test("somebody else's live check-in here is not mine to walk into",
        () async {
      // The seat is occupied by another member: this decision does not
      // refuse it (the server does), and it must not mistake their row
      // for mine.
      final theirs = Reservation(
        id: 'res-theirs',
        workspaceId: 'ws-1',
        seatId: _seat,
        memberId: 'member-2',
        startsAt: kTestNow.subtract(const Duration(hours: 1)),
        endsAt: kTestNow.add(const Duration(hours: 3)),
        status: ReservationStatus.checkedIn,
        checkedInAt: kTestNow.subtract(const Duration(hours: 1)),
      );

      final outcome = await actOnSpace(repo, _request(
        SpaceAction.checkIn,
        day: [theirs],
      ));

      expect(outcome, isA<WalkedUp>(),
          reason: 'the refusal is the server\'s to make, on its own rules');
    });
  });

  group('check out', () {
    test('my live check-in here is the one released', () async {
      final live = _mine(
        status: ReservationStatus.checkedIn,
        checkedInAt: kTestNow.subtract(const Duration(hours: 1)),
      );
      repo.reservations.add(live);

      final outcome = await actOnSpace(repo, _request(
        SpaceAction.checkOut,
        day: [live],
      ));

      expect(outcome, isA<CheckedOut>());
      expect((outcome as CheckedOut).reservationId, 'res-mine');
    });

    test('#1083 — with two live seats, THIS seat is released', () async {
      // simultaneous_reservations > 1: the seat predicate is the whole
      // point. Without it the branch took firstOrNull of an unordered
      // list and checked the member out of whichever came first.
      final here = _mine(
        status: ReservationStatus.checkedIn,
        checkedInAt: kTestNow.subtract(const Duration(minutes: 30)),
      );
      final elsewhere = _mine(
        id: 'res-elsewhere',
        seatId: 'seat-9',
        status: ReservationStatus.checkedIn,
        checkedInAt: kTestNow.subtract(const Duration(hours: 2)),
      );
      repo.reservations.addAll([here, elsewhere]);

      final outcome = await actOnSpace(repo, _request(
        SpaceAction.checkOut,
        day: [elsewhere, here],
      ));

      expect((outcome as CheckedOut).reservationId, 'res-mine',
          reason: 'scanning a seat releases THAT seat');
      expect(
        repo.reservations.firstWhere((r) => r.id == 'res-elsewhere').status,
        ReservationStatus.checkedIn,
        reason: 'the other seat is untouched',
      );
    });

    test('nothing live here is a value, not an exception — the plan may '
        'have just updated', () async {
      final outcome = await actOnSpace(repo, _request(
        SpaceAction.checkOut,
        day: const [],
      ));

      expect(outcome, isA<NoActiveCheckIn>());
    });
  });

  group('reserve', () {
    test('reports what the server was ASKED to do about checking in, '
        'because saying false while it checked them in is the '
        'confirmation lying (#687)', () async {
      final outcome = await actOnSpace(repo, _request(
        SpaceAction.reserve,
        day: const [],
        checkInNow: true,
      ));

      expect((outcome as Reserved).checkedIn, isTrue);
    });
  });

  test('it does not catch — the server\'s own words reach the caller '
      '(#1030)', () async {
    // The fake refuses exactly as the server does, and that refusal must
    // arrive untouched: `bookingErrorText` maps the sentence to the
    // member's language, and it needs the sentence to map. No injection
    // hook — the same precedent as `book_seat_test`.
    final lastWeek = kTestNow.subtract(const Duration(days: 7));

    await expectLater(
      actOnSpace(repo, _request(
        SpaceAction.reserve,
        day: const [],
        start: lastWeek,
        end: lastWeek.add(const Duration(hours: 2)),
      )),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message',
            contains('lies entirely in the past')),
      ),
    );
  });
}
