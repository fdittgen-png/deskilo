// SPDX-License-Identifier: 0BSD
//
// #637 (migration 0122) — ONE booking contract. The past-day guard
// ('lies entirely in the past') and the walk-up-today guard ('must
// start today') lived in create_reservation ALONE, so kiosk_act — which
// validates through enforce_booking_rules and never calls
// create_reservation — accepted at the wall what the plan, the Reserve
// hub and a QR scan all refuse.
//
// The guards MOVED into enforce_booking_rules, the shared chokepoint.
// The pins below are the anti-drift fence: exactly one implementation
// of each guard may exist, in the chokepoint, and create_reservation
// must not grow a second copy back. The behavior half asks the fake —
// whose kiosk path now goes through the same mirrored rule set.
import 'dart:io';

import 'package:deskilo/features/reservations/domain/booking_error_text.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/test_clock.dart';

/// The two substrings the client maps in [bookingErrorText]. They are a
/// wire contract: the server raises them, the client recognizes them,
/// and neither side may reword one alone.
const _pastSubstring = 'lies entirely in the past';
const _walkUpSubstring = 'must start today';

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(kTestNow.year, kTestNow.month, kTestNow.day, hour, minute);

DateTime _dayOffset(int days, int hour) {
  final d = kTestNow.add(Duration(days: days));
  return DateTime(d.year, d.month, d.day, hour);
}

void main() {
  group('server contract (migration 0122, #637)', () {
    final sql = File('supabase/migrations/0122_enforcement_parity.sql')
        .readAsStringSync();

    /// The body of [name] — from its create statement to the next one.
    String body(String name) {
      final start = sql.indexOf('create or replace function public.$name');
      expect(start, greaterThanOrEqualTo(0), reason: '$name must exist');
      final next = sql.indexOf('create or replace function', start + 1);
      return next < 0 ? sql.substring(start) : sql.substring(start, next);
    }

    /// [body] without its comment lines — the CODE, so a comment that
    /// merely NAMES a guard can never satisfy (or break) a pin.
    String code(String text) => text
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('--'))
        .join('\n');

    test('THE chokepoint carries both guards and the policy read', () {
      final enforce = code(body('enforce_booking_rules'));
      expect(enforce, contains("raise exception 'the booking $_pastSubstring'"));
      expect(enforce,
          contains("raise exception 'a walk-up check-in $_walkUpSubstring'"));
      expect(
        enforce,
        contains("coalesce(rules->>'"
            '${BookingPolicies.allowPastBookingsKey}'
            "', 'false') <> 'true'"),
        reason: 'the past guard still asks the owner switch',
      );
      expect(enforce, contains('if p_walk_up'),
          reason: 'the walk-up guard keys on the chokepoint own flag');
    });

    test('the past guard stays DAY-level — a window earlier the SAME '
        'day is still legal', () {
      expect(
        code(body('enforce_booking_rules')),
        contains("((p_ends_at - interval '1 second') at time zone tz)::date\n"
            "       < (now() at time zone tz)::date"),
        reason: 'comparing DATES, never instants',
      );
    });

    test('create_reservation no longer implements either guard — the '
        'move left no second copy', () {
      final create = code(body('create_reservation'));
      expect(create, isNot(contains(_pastSubstring)));
      expect(create, isNot(contains(_walkUpSubstring)));
      expect(create, isNot(contains(BookingPolicies.allowPastBookingsKey)));
      // It still routes through the chokepoint, which now enforces them.
      expect(create,
          contains('public.enforce_booking_rules(p_workspace_id, v_starts, '
              'v_ends, p_check_in)'));
    });

    test('each pinned refusal is raised in exactly ONE function', () {
      for (final substring in [_pastSubstring, _walkUpSubstring]) {
        final raises = RegExp("raise exception '[^']*$substring[^']*'")
            .allMatches(sql)
            .length;
        expect(raises, 1,
            reason: '$substring must have a single implementation');
      }
    });

    test("kiosk_act's level path grants what create_reservation grants — "
        'owners and admins included', () {
      expect(
        code(body('kiosk_act')),
        contains('if not (v_subject.can_reserve_level or v_subject.is_owner\n'
            '            or v_subject.is_admin) then'),
      );
      // create_reservation's own condition, unchanged, for comparison.
      expect(
        code(body('create_reservation')),
        contains('if not (v_member.can_reserve_level or v_member.is_owner\n'
            '                or v_member.is_admin) then'),
      );
    });

    test('walkup_only means spontaneity, not the evening (#637)', () {
      final enforce = code(body('enforce_booking_rules'));
      expect(enforce, contains('v_spontaneous := p_walk_up;'));
      expect(enforce, isNot(contains('v_spontaneous := p_walk_up and')),
          reason: "0120's evening-only shape is gone from the gate");
      // 'off' still refuses walk-ups: its arm never consults spontaneity.
      expect(
        enforce,
        contains("if v_mode = '${OutsideHoursMode.off.wire}' "
            'and v_touches_outside then'),
      );
    });

    test('the header states where each body came from and that the '
        'guards MOVED', () {
      expect(sql, contains('0120'));
      expect(sql, contains('0116'));
      expect(sql, contains('0119'));
      expect(sql, contains('MOVE'),
          reason: 'a reader must not wonder whether two copies disagree');
    });
  });

  group('the client still maps both refusals (#637)', () {
    test('the moved substrings keep their explanations', () {
      expect(
        bookingErrorText(
            null,
            const PostgrestException(
                message: 'the booking lies entirely in the past'),
            'fallback'),
        'This booking lies entirely in the past.',
      );
      expect(
        bookingErrorText(
            null,
            const PostgrestException(
                message: 'a walk-up check-in must start today'),
            'fallback'),
        'A walk-up check-in must start today.',
      );
    });
  });

  // The behavior half: the fake mirrors ONE rule set, asked by the
  // create path AND the kiosk path — the parity this issue is about.
  group('the kiosk obeys the same contract (#637)', () {
    test('a kiosk walk-up for TOMORROW is refused, as on every other '
        'entry point', () async {
      final repo = FakeReservationRepository();
      await expectLater(
        repo.kioskAct(
          workspaceId: 'ws-1',
          badgeToken: 'badge-1',
          action: 'check_in',
          seatId: 'seat-1',
          startsAt: _dayOffset(1, 10),
          endsAt: _dayOffset(1, 12),
        ),
        throwsA(predicate((e) => e.toString().contains(_walkUpSubstring))),
      );
      expect(repo.kioskActs, isEmpty,
          reason: 'the refusal happens before the act is recorded');
    });

    test('a kiosk booking on a day that already ended is refused, and '
        'the backfill switch opens it', () async {
      final repo = FakeReservationRepository();
      await expectLater(
        repo.kioskAct(
          workspaceId: 'ws-1',
          badgeToken: 'badge-1',
          action: 'reserve',
          seatId: 'seat-1',
          startsAt: _dayOffset(-1, 8),
          endsAt: _dayOffset(-1, 12),
        ),
        throwsA(predicate((e) => e.toString().contains(_pastSubstring))),
      );
      repo.allowPastBookings = true;
      final id = await repo.kioskAct(
        workspaceId: 'ws-1',
        badgeToken: 'badge-1',
        action: 'reserve',
        seatId: 'seat-1',
        startsAt: _dayOffset(-1, 8),
        endsAt: _dayOffset(-1, 12),
      );
      expect(id, isNotEmpty);
    });

    test('a walk-up EARLIER THE SAME DAY still passes at the kiosk — '
        'the guard is day-level, not instant-level', () async {
      final repo = FakeReservationRepository();
      final id = await repo.kioskAct(
        workspaceId: 'ws-1',
        badgeToken: 'badge-1',
        action: 'check_in',
        seatId: 'seat-1',
        startsAt: _at(8),
        endsAt: _at(12),
      );
      expect(id, isNotEmpty);
    });

    test('the outside-hours mode reaches the kiosk too', () async {
      final repo = FakeReservationRepository()
        ..outsideHoursMode = OutsideHoursMode.off;
      await expectLater(
        repo.kioskAct(
          workspaceId: 'ws-1',
          badgeToken: 'badge-1',
          action: 'check_in',
          seatId: 'seat-1',
          startsAt: _at(17),
          endsAt: DateTime(kTestNow.year, kTestNow.month, kTestNow.day + 1),
        ),
        throwsA(isA<PostgrestException>().having((e) => e.message, 'message',
            contains('outside the opening hours'))),
      );
    });
  });
}
