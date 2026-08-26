// SPDX-License-Identifier: 0BSD
//
// #624 (migration 0118) + #634 (migration 0120) — THE outside-opening-
// hours policy: one booking_rules string key, outside_hours_mode, with
// FOUR mutually exclusive answers ('off' | 'walkup_only' | 'free' |
// 'charged', absent = 'charged'). #634 folded #600's grid_within_hours
// switch into it: that key is now read-only legacy and resolves to
// 'walkup_only'.
//
// ENFORCEMENT (0120) refuses on the wider predicate — a window that
// LEAVES the working day at either edge, spill included. BILLING (0118)
// is deliberately untouched: free/exempt treatment still keys on
// ENTIRELY-outside windows, and the cap and the bill agree because
// assert_member_quota and member_statement filter through the SAME SQL
// predicate — all pinned below.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/test_clock.dart';

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(kTestNow.year, kTestNow.month, kTestNow.day, hour, minute);

/// Midnight ending the test day — the canonical overtime walk-up end.
DateTime get _midnight =>
    DateTime(kTestNow.year, kTestNow.month, kTestNow.day + 1);

void main() {
  group('OutsideHoursMode wire round-trip (#624)', () {
    test('absent reads as charged — the server default', () {
      expect(const BookingPolicies().outsideHoursMode,
          OutsideHoursMode.charged);
      expect(BookingPolicies.fromRules(null).outsideHoursMode,
          OutsideHoursMode.charged);
      expect(BookingPolicies.fromRules({}).outsideHoursMode,
          OutsideHoursMode.charged);
    });

    test('each wire string reads back as its mode', () {
      for (final mode in OutsideHoursMode.values) {
        expect(
          BookingPolicies.fromRules(
                  {BookingPolicies.outsideHoursModeKey: mode.wire})
              .outsideHoursMode,
          mode,
          reason: 'wire ${mode.wire} must round-trip',
        );
      }
    });

    test('an unknown wire value falls back to charged', () {
      expect(
        BookingPolicies.fromRules(
                {BookingPolicies.outsideHoursModeKey: 'sometimes'})
            .outsideHoursMode,
        OutsideHoursMode.charged,
      );
    });

    test('the mode key does not disturb the #600 switches', () {
      final p = BookingPolicies.fromRules({
        BookingPolicies.allowPastBookingsKey: true,
        BookingPolicies.outsideHoursModeKey: 'free',
      });
      expect(p.allowPastBookings, isTrue);
      expect(p.outsideHoursMode, OutsideHoursMode.free);
      expect(p.copyWith(outsideHoursMode: OutsideHoursMode.off)
          .allowPastBookings, isTrue);
    });
  });

  // #634 — the legacy resolution, mirroring migration 0120's gate:
  //   coalesce(outside_hours_mode,
  //            case when grid_within_hours = 'true'
  //                 then 'walkup_only' else 'charged' end)
  group('the retired grid switch resolves as a mode (#634)', () {
    test('grid_within_hours = true with no mode reads as walkupOnly', () {
      for (final stored in [true, 'true']) {
        expect(
          BookingPolicies.fromRules(
                  {BookingPolicies.gridWithinHoursKey: stored})
              .outsideHoursMode,
          OutsideHoursMode.walkupOnly,
          reason: 'stored as $stored, the #600 switch IS walkup_only',
        );
      }
    });

    test('grid_within_hours = false with no mode reads as charged', () {
      expect(
        BookingPolicies.fromRules(
                {BookingPolicies.gridWithinHoursKey: false})
            .outsideHoursMode,
        OutsideHoursMode.charged,
      );
    });

    test('an explicit mode always wins over the legacy key', () {
      for (final mode in OutsideHoursMode.values) {
        expect(
          BookingPolicies.fromRules({
            BookingPolicies.gridWithinHoursKey: true,
            BookingPolicies.outsideHoursModeKey: mode.wire,
          }).outsideHoursMode,
          mode,
          reason: '${mode.wire} must beat grid_within_hours',
        );
      }
    });

    test('an unknown mode string reads as charged, legacy key or not',
        () {
      expect(
        BookingPolicies.fromRules({
          BookingPolicies.outsideHoursModeKey: 'sometimes',
        }).outsideHoursMode,
        OutsideHoursMode.charged,
      );
      expect(
        BookingPolicies.fromRules({
          BookingPolicies.gridWithinHoursKey: true,
          BookingPolicies.outsideHoursModeKey: 'sometimes',
        }).outsideHoursMode,
        OutsideHoursMode.charged,
        reason: "the server's coalesce short-circuits on ANY present "
            'value — a written-but-unknown mode never falls back',
      );
    });

    test('walkupOnly is the LAST enum value — append-only', () {
      expect(OutsideHoursMode.values.last, OutsideHoursMode.walkupOnly);
      expect(OutsideHoursMode.walkupOnly.wire, 'walkup_only');
    });
  });

  group('mode off refuses outside-only windows (fake mirror, #624)', () {
    test('the overtime walk-up 17:00→midnight is refused', () async {
      final repo = FakeReservationRepository()
        ..outsideHoursMode = OutsideHoursMode.off;
      await expectLater(
        repo.create(
          workspaceId: 'ws-1',
          seatId: 'seat-1',
          startsAt: _at(17),
          endsAt: _midnight,
          checkIn: true,
        ),
        throwsA(isA<PostgrestException>().having((e) => e.message,
            'message', contains('outside the opening hours'))),
      );
      expect(repo.reservations, isEmpty);
    });

    test('a non-walk-up early-morning booking is refused too', () async {
      final repo = FakeReservationRepository()
        ..outsideHoursMode = OutsideHoursMode.off;
      await expectLater(
        repo.create(
          workspaceId: 'ws-1',
          seatId: 'seat-1',
          startsAt: _at(6),
          endsAt: _at(7, 30),
        ),
        throwsA(isA<PostgrestException>().having((e) => e.message,
            'message', contains('outside the opening hours'))),
      );
    });

    test('a regular inside-hours window is untouched by off', () async {
      final repo = FakeReservationRepository()
        ..outsideHoursMode = OutsideHoursMode.off;
      final id = await repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _at(10),
        endsAt: _at(12),
      );
      expect(id, isNotEmpty);
    });

    // #634 widened enforcement: SPILL counts too. If the space closes
    // at 17:00, a booking until 20:00 is not sensible under 'off'.
    test('a SPILLING window 16:00→20:00 is refused under off too',
        () async {
      final repo = FakeReservationRepository()
        ..outsideHoursMode = OutsideHoursMode.off;
      await expectLater(
        repo.create(
          workspaceId: 'ws-1',
          seatId: 'seat-1',
          startsAt: _at(16),
          endsAt: _at(20),
        ),
        throwsA(isA<PostgrestException>().having((e) => e.message,
            'message', contains('outside the opening hours'))),
      );
      expect(repo.reservations, isEmpty);
    });

    test('free and charged both allow the outside-only walk-up',
        () async {
      for (final mode in [OutsideHoursMode.free, OutsideHoursMode.charged]) {
        final repo = FakeReservationRepository()..outsideHoursMode = mode;
        final id = await repo.create(
          workspaceId: 'ws-1',
          seatId: 'seat-1',
          startsAt: _at(17),
          endsAt: _midnight,
          checkIn: true,
        );
        expect(id, isNotEmpty, reason: '$mode must allow overtime');
      }
    });

    test('free and charged allow the spilling and early windows too',
        () async {
      for (final mode in [OutsideHoursMode.free, OutsideHoursMode.charged]) {
        final repo = FakeReservationRepository()..outsideHoursMode = mode;
        expect(
          await repo.create(
            workspaceId: 'ws-1',
            seatId: 'seat-1',
            startsAt: _at(16),
            endsAt: _at(20),
          ),
          isNotEmpty,
          reason: '$mode must allow the spill',
        );
        expect(
          await repo.create(
            workspaceId: 'ws-1',
            seatId: 'seat-2',
            startsAt: _at(6),
            endsAt: _at(7, 30),
          ),
          isNotEmpty,
          reason: '$mode must allow the early morning',
        );
      }
    });
  });

  // #634 — walkup_only IS the retired grid switch, generalized: the
  // spontaneous evening run survives, everything booked ahead does not.
  group('mode walkup_only keeps only the spontaneous shape (#634)', () {
    test('the evening walk-up 17:00→midnight is ALLOWED', () async {
      final repo = FakeReservationRepository()
        ..outsideHoursMode = OutsideHoursMode.walkupOnly;
      final id = await repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _at(17),
        endsAt: _midnight,
        checkIn: true,
      );
      expect(id, isNotEmpty);
    });

    test('reserving the same evening window AHEAD is refused', () async {
      final repo = FakeReservationRepository()
        ..outsideHoursMode = OutsideHoursMode.walkupOnly;
      await expectLater(
        repo.create(
          workspaceId: 'ws-1',
          seatId: 'seat-1',
          startsAt: _at(17),
          endsAt: _at(20),
        ),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            allOf(contains('outside the opening hours'),
                contains('spontaneous check-in')))),
      );
      expect(repo.reservations, isEmpty);
    });

    test('an early-morning booking and a spilling window are refused',
        () async {
      for (final window in [
        (_at(6), _at(7, 30)),
        (_at(16), _at(20)),
      ]) {
        final repo = FakeReservationRepository()
          ..outsideHoursMode = OutsideHoursMode.walkupOnly;
        await expectLater(
          repo.create(
            workspaceId: 'ws-1',
            seatId: 'seat-1',
            startsAt: window.$1,
            endsAt: window.$2,
          ),
          throwsA(isA<PostgrestException>().having((e) => e.message,
              'message', contains('outside the opening hours'))),
        );
      }
    });

    test('a regular inside-hours window is untouched', () async {
      final repo = FakeReservationRepository()
        ..outsideHoursMode = OutsideHoursMode.walkupOnly;
      expect(
        await repo.create(
          workspaceId: 'ws-1',
          seatId: 'seat-1',
          startsAt: _at(10),
          endsAt: _at(12),
        ),
        isNotEmpty,
      );
    });
  });

  group('server contract (migration 0118)', () {
    final sql = File('supabase/migrations/0118_outside_hours_policy.sql')
        .readAsStringSync();

    /// The body of [name] — from its create statement to the next one.
    String body(String name) {
      final start = sql.indexOf('create or replace function public.$name');
      expect(start, greaterThanOrEqualTo(0), reason: '$name must exist');
      final next =
          sql.indexOf('create or replace function', start + 1);
      return next < 0 ? sql.substring(start) : sql.substring(start, next);
    }

    test('the shared predicate exists and reads the client key with the '
        'charged default', () {
      final helper = body('reservation_counts_for_usage');
      expect(
        helper,
        contains("coalesce(rules->>'"
            '${BookingPolicies.outsideHoursModeKey}'
            "', '${OutsideHoursMode.charged.wire}')"),
      );
      expect(helper, contains("v_mode = '${OutsideHoursMode.free.wire}'"));
    });

    test('the cap and the bill agree: assert_member_quota AND '
        'member_statement both filter through the SAME predicate', () {
      expect(body('assert_member_quota'),
          contains('public.reservation_counts_for_usage(r, v_rules, v_tz)'));
      expect(body('member_statement'),
          contains('public.reservation_counts_for_usage(r, v_rules, v_tz)'));
    });

    test('enforce_booking_rules v7 refuses mode off with the pinned '
        'substring the client maps', () {
      final enforce = body('enforce_booking_rules');
      expect(
        enforce,
        contains("coalesce(rules->>'"
            '${BookingPolicies.outsideHoursModeKey}'
            "', '${OutsideHoursMode.charged.wire}') = "
            "'${OutsideHoursMode.off.wire}'"),
      );
      expect(enforce, contains('outside the opening hours'));
    });
  });

  group('server contract (migration 0120, #634)', () {
    final sql = File('supabase/migrations/0120_unified_outside_hours.sql')
        .readAsStringSync();

    /// The body of [name] — from its create statement to the next one.
    String body(String name) {
      final start = sql.indexOf('create or replace function public.$name');
      expect(start, greaterThanOrEqualTo(0), reason: '$name must exist');
      final next = sql.indexOf('create or replace function', start + 1);
      return next < 0 ? sql.substring(start) : sql.substring(start, next);
    }

    test('0120 documents all four modes and the gate refuses on two',
        () {
      for (final mode in OutsideHoursMode.values) {
        expect(sql, contains(mode.wire),
            reason: '${mode.wire} must appear in the migration');
      }
      // Only two of them REFUSE; free and charged fall through the gate
      // untouched, exactly as before #634.
      final enforce = body('enforce_booking_rules');
      expect(enforce, contains("v_mode = '${OutsideHoursMode.off.wire}'"));
      expect(enforce,
          contains("v_mode = '${OutsideHoursMode.walkupOnly.wire}'"));
      expect(enforce, isNot(contains("v_mode = '"
          "${OutsideHoursMode.free.wire}'")));
    });

    test('the legacy fallback expression resolves the mode ONCE', () {
      expect(
        body('enforce_booking_rules'),
        contains("coalesce(\n"
            "    rules->>'${BookingPolicies.outsideHoursModeKey}',\n"
            "    case when coalesce(rules->>'"
            "${BookingPolicies.gridWithinHoursKey}', 'false') = 'true'\n"
            "         then '${OutsideHoursMode.walkupOnly.wire}' "
            "else '${OutsideHoursMode.charged.wire}' end)"),
      );
    });

    test('the two refusals keep the pinned substring, and the '
        'walkup_only one names the spontaneous check-in', () {
      final enforce = body('enforce_booking_rules');
      final refusals = RegExp(r"raise exception '([^']*)'")
          .allMatches(enforce)
          .map((m) => m.group(1)!)
          .where((m) => m.contains('opening hours'))
          .toList();
      expect(refusals, hasLength(2));
      expect(refusals.every((m) => m.contains('outside the opening hours')),
          isTrue);
      expect(refusals.any((m) => m.contains('spontaneous check-in')), isTrue);
    });

    test('the grid_within_hours REFUSAL block is gone — the key is only '
        'read as the legacy fallback', () {
      final enforce = body('enforce_booking_rules');
      expect(enforce, isNot(contains('stay within the working hours')),
          reason: "#600's refusal now lives in the unified gate");
      // Comments may name the retired key; the CODE reads it once.
      final code = enforce
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('--'))
          .join('\n');
      expect(
        RegExp(BookingPolicies.gridWithinHoursKey).allMatches(code),
        hasLength(1),
        reason: 'read exactly once, in the fallback expression',
      );
    });

    test('BILLING is untouched: 0120 redefines nothing but the gate', () {
      expect(sql, isNot(contains('create or replace function '
          'public.reservation_counts_for_usage')));
      expect(sql, isNot(contains(
          'create or replace function public.assert_member_quota')));
      expect(sql, isNot(contains(
          'create or replace function public.member_statement')));
      expect(sql, contains('BILLING SCOPE IS UNCHANGED'),
          reason: 'the asymmetry must be stated in the header');
    });
  });
}
