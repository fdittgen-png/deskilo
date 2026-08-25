// SPDX-License-Identifier: 0BSD
//
// #628 (migration 0119) — "one place at a time" (#412) becomes a
// configurable allowance. Three server call sites used to hard-code 1:
// enforce_one_place, check_in_reservation's still-running-elsewhere
// guard and kiosk_act's twin guards. They now all ask ONE helper,
// member_simultaneous_allowance, which resolves
//   members.max_simultaneous_reservations
//     → booking_rules.simultaneous_reservations
//       → 1 (today's behavior, exactly).
// Both pinned substrings the client maps survive verbatim.
import 'dart:io';

import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
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
  ReservationStatus status = ReservationStatus.reserved,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: seatId,
      memberId: 'member-1',
      startsAt: start ?? kTestNow.subtract(const Duration(hours: 1)),
      endsAt: end ?? kTestNow.add(const Duration(hours: 2)),
      status: status,
      checkedInAt: status == ReservationStatus.checkedIn ? kTestNow : null,
    );

Matcher _refuses(String substring) => throwsA(isA<PostgrestException>()
    .having((e) => e.message, 'message', contains(substring)));

void main() {
  group('allowance resolution — member > workspace > 1 (#628)', () {
    test('nothing configured anywhere is one place at a time', () {
      expect(const BookingPolicies().simultaneousReservations, 1);
      expect(BookingPolicies.fromRules(null).simultaneousReservations, 1);
      expect(BookingPolicies.fromRules({}).simultaneousReservations, 1);
      expect(BookingPolicies.allowanceFor(null, const BookingPolicies()), 1);
    });

    test('the workspace key is read as an int, string form included', () {
      for (final wire in <Object>[3, '3']) {
        expect(
          BookingPolicies.fromRules(
                  {BookingPolicies.simultaneousReservationsKey: wire})
              .simultaneousReservations,
          3,
          reason: 'wire $wire must read as 3',
        );
      }
    });

    test('an invalid workspace value falls back to 1, never opens up', () {
      for (final wire in <Object?>[null, 'lots', '', 0, -4, true]) {
        expect(
          BookingPolicies.fromRules(
                  {BookingPolicies.simultaneousReservationsKey: wire})
              .simultaneousReservations,
          1,
          reason: 'wire $wire must fall back to 1',
        );
      }
    });

    test('the workspace value is clamped to the server 1..20 fence', () {
      expect(
        BookingPolicies.fromRules(
                {BookingPolicies.simultaneousReservationsKey: 99})
            .simultaneousReservations,
        BookingPolicies.maxSimultaneous,
      );
    });

    test('the member permission wins over the workspace default', () {
      final ws = BookingPolicies.fromRules(
          {BookingPolicies.simultaneousReservationsKey: 2});
      expect(BookingPolicies.allowanceFor(null, ws), 2,
          reason: 'no override: follow the workspace');
      expect(BookingPolicies.allowanceFor(5, ws), 5,
          reason: 'the explicit permission wins, upward');
      expect(BookingPolicies.allowanceFor(1, ws), 1,
          reason: 'the explicit permission wins, downward too');
    });

    test('the key does not disturb the #600/#624 policies', () {
      final p = BookingPolicies.fromRules({
        BookingPolicies.allowPastBookingsKey: true,
        BookingPolicies.outsideHoursModeKey: 'free',
        BookingPolicies.simultaneousReservationsKey: 4,
      });
      expect(p.allowPastBookings, isTrue);
      expect(p.outsideHoursMode, OutsideHoursMode.free);
      expect(p.simultaneousReservations, 4);
      expect(p.copyWith(simultaneousReservations: 2).allowPastBookings,
          isTrue);
    });
  });

  group('the allowance decides the overlap refusal (fake mirror)', () {
    test('allowance 1 still refuses the second overlapping booking — '
        'the #412 behavior is untouched', () async {
      final repo = FakeReservationRepository()..reservations.add(_mine());
      expect(repo.simultaneousAllowance, 1,
          reason: 'the fake defaults to the server fallback');
      await expectLater(
        repo.create(
          workspaceId: 'ws-1',
          seatId: 'seat-2',
          startsAt: kTestNow,
          endsAt: kTestNow.add(const Duration(hours: 2)),
        ),
        _refuses('you already have a reservation in that period'),
      );
      expect(repo.reservations, hasLength(1));
    });

    test('allowance 2 allows the SECOND overlapping booking and refuses '
        'the third', () async {
      final repo = FakeReservationRepository()
        ..simultaneousAllowance = 2
        ..reservations.add(_mine());
      await repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-2',
        startsAt: kTestNow,
        endsAt: kTestNow.add(const Duration(hours: 2)),
      );
      expect(repo.reservations, hasLength(2));
      await expectLater(
        repo.create(
          workspaceId: 'ws-1',
          seatId: 'seat-3',
          startsAt: kTestNow,
          endsAt: kTestNow.add(const Duration(hours: 2)),
        ),
        _refuses('you already have a reservation in that period'),
      );
      expect(repo.reservations, hasLength(2),
          reason: 'the third overlap never lands');
    });

    test('check-in elsewhere refuses at allowance 1 and goes through at 2',
        () async {
      for (final allowance in [1, 2]) {
        final repo = FakeReservationRepository()
          ..simultaneousAllowance = allowance
          ..reservations.add(_mine(status: ReservationStatus.checkedIn))
          ..reservations.add(_mine(
            id: 'res-next',
            seatId: 'seat-2',
            start: kTestNow.subtract(const Duration(minutes: 5)),
            end: kTestNow.add(const Duration(hours: 4)),
          ));
        if (allowance == 1) {
          await expectLater(
            repo.checkIn('res-next'),
            _refuses('already checked in elsewhere'),
          );
        } else {
          await repo.checkIn('res-next');
          expect(
            repo.reservations.firstWhere((r) => r.id == 'res-next').status,
            ReservationStatus.checkedIn,
          );
        }
      }
    });

    test('a STALE check-in still completes itself at allowance 2 — the '
        'auto-complete above the guard is untouched', () async {
      final repo = FakeReservationRepository()
        ..simultaneousAllowance = 2
        ..reservations.add(_mine(
          status: ReservationStatus.checkedIn,
          start: kTestNow.subtract(const Duration(hours: 4)),
          end: kTestNow.subtract(const Duration(hours: 1)),
        ))
        ..reservations.add(_mine(
          id: 'res-next',
          seatId: 'seat-2',
          start: kTestNow,
          end: kTestNow.add(const Duration(hours: 4)),
        ));
      await repo.checkIn('res-next');
      final stale = repo.reservations.firstWhere((r) => r.id == 'res-mine');
      expect(stale.status, ReservationStatus.completed);
      expect(stale.checkedOutAt, stale.endsAt);
    });
  });

  group('server contract (migration 0119)', () {
    final sql =
        File('supabase/migrations/0119_simultaneous_and_autovalidate.sql')
            .readAsStringSync();

    /// The body of [name] — from its create statement to the next one.
    String body(String name) {
      final start = sql.indexOf('create or replace function public.$name');
      expect(start, greaterThanOrEqualTo(0), reason: '$name must exist');
      final next = sql.indexOf('create or replace function', start + 1);
      return next < 0 ? sql.substring(start) : sql.substring(start, next);
    }

    test('ONE helper resolves the allowance: member column, then the '
        'client booking_rules key, then 1', () {
      final helper = body('member_simultaneous_allowance');
      expect(helper, contains('m.max_simultaneous_reservations'));
      expect(
        helper,
        contains("w.booking_rules->>'"
            '${BookingPolicies.simultaneousReservationsKey}'
            "'"),
      );
      expect(helper, contains('return 1;'),
          reason: 'the absent/invalid fallback is one place at a time');
      expect(helper, contains('least(v_ws, ${BookingPolicies.maxSimultaneous})'),
          reason: 'the client mirrors the same ceiling');
    });

    test('all THREE enforcement sites call the shared helper — no '
        'duplicated resolution', () {
      expect(body('enforce_one_place'),
          contains('public.member_simultaneous_allowance(new.member_id)'));
      expect(body('check_in_reservation'),
          contains('public.member_simultaneous_allowance(v_res.member_id)'));
      // kiosk_act guards BOTH its level path and its seat path.
      final kiosk = body('kiosk_act');
      expect(
        RegExp(r'public\.member_simultaneous_allowance\(v_subject\.id\)')
            .allMatches(kiosk)
            .length,
        2,
        reason: 'the level path and the seat path both ask the helper',
      );
    });

    test('the refusals COUNT instead of existence-testing, and keep the '
        'substrings bookingErrorText pins', () {
      final one = body('enforce_one_place');
      expect(one, contains('v_overlaps >= v_allowance'));
      expect(one, contains('you already have a reservation in that period'));
      expect(body('check_in_reservation'),
          contains('already checked in elsewhere'));
      expect(body('kiosk_act'), contains('already checked in elsewhere'));
    });

    test('the per-member permission is a bounded column with a setter '
        'modeled on set_member_reservation_limit (0044)', () {
      expect(
        sql,
        contains('check (max_simultaneous_reservations between 1 and '
            '${BookingPolicies.maxSimultaneous})'),
      );
      final setter = body('set_member_simultaneous_limit');
      expect(setter, contains('not an admin of this workspace'));
      expect(setter, contains('cannot set your own simultaneous limit'),
          reason: 'governance, not self-service — the 0044 rule');
      expect(sql,
          contains('revoke execute on function '
              'public.set_member_simultaneous_limit(uuid, int)'));
    });
  });
}
