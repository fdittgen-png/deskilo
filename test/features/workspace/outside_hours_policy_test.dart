// SPDX-License-Identifier: 0BSD
//
// #624 (migration 0118) — the outside-opening-hours booking policy.
// One booking_rules string key, outside_hours_mode ('off' | 'free' |
// 'charged', absent = 'charged'), governing bookings whose window lies
// ENTIRELY outside the working hours. 'off' refuses them server-side
// (pinned substring); 'free' never counts them; 'charged' counts them
// unless the member holds a regular same-day reservation. The cap and
// the bill must agree: assert_member_quota and member_statement filter
// through the SAME SQL predicate — pinned below.
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
      expect(p.gridWithinHours, isFalse);
      expect(p.outsideHoursMode, OutsideHoursMode.free);
      expect(p.copyWith(outsideHoursMode: OutsideHoursMode.off)
          .allowPastBookings, isTrue);
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

    test('a window merely touching the working hours is regular — '
        '16:00→20:00 passes under off', () async {
      final repo = FakeReservationRepository()
        ..outsideHoursMode = OutsideHoursMode.off;
      final id = await repo.create(
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _at(16),
        endsAt: _at(20),
      );
      expect(id, isNotEmpty);
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
}
