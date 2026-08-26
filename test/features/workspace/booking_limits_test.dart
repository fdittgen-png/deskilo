// SPDX-License-Identifier: 0BSD
//
// #649 — the three numeric booking limits (`advance_horizon_days`,
// `min_duration_minutes`, `max_duration_minutes`). The server has
// enforced all three since migration 0006 and coalesced them to 90 / 30
// / 1440 when absent; nothing in the app could ever set them, so an
// owner met the limits only by hitting them.
//
// The client mirror MUST agree with the server's fallbacks. Verified
// live against the hosted project: the `workspaces.booking_rules` column
// DEFAULT (migration 0006) already writes all three keys, so in practice
// every existing row carries 90 / 30 / 1440 explicitly — the coalesce is
// the fallback for a row whose booking_rules was replaced wholesale, not
// the normal path. Either way the number the screen shows has to be the
// number the server would use, so the pins below read the fallbacks
// straight out of the migration and break if the two ever diverge.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading the wire', () {
    test('an absent key reads the server fallback', () {
      const p = BookingPolicies();
      expect(p.advanceHorizonDays, 90);
      expect(p.minDurationMinutes, 30);
      expect(p.maxDurationMinutes, 1440);

      final fromEmpty = BookingPolicies.fromRules(const {});
      expect(fromEmpty.advanceHorizonDays, 90);
      expect(fromEmpty.minDurationMinutes, 30);
      expect(fromEmpty.maxDurationMinutes, 1440);
      expect(BookingPolicies.fromRules(null).advanceHorizonDays, 90);
    });

    test('a jsonb number and its string form read the same', () {
      for (final value in <Object>[45, '45', 45.0, 45.9]) {
        expect(
          BookingPolicies.fromRules({'min_duration_minutes': value})
              .minDurationMinutes,
          45,
          reason: '$value (${value.runtimeType}) must read as 45',
        );
      }
    });

    test('unreadable values fall back rather than throwing', () {
      for (final value in <Object?>[null, 'soon', '', true, <String>[]]) {
        expect(
          BookingPolicies.fromRules({'advance_horizon_days': value})
              .advanceHorizonDays,
          90,
        );
      }
    });

    test('out-of-range values are clamped, never accepted raw', () {
      expect(
        BookingPolicies.fromRules(const {'advance_horizon_days': 0})
            .advanceHorizonDays,
        BookingPolicies.minHorizonDays,
      );
      expect(
        BookingPolicies.fromRules(const {'advance_horizon_days': 99999})
            .advanceHorizonDays,
        BookingPolicies.maxHorizonDays,
      );
      expect(
        BookingPolicies.fromRules(const {'min_duration_minutes': -5})
            .minDurationMinutes,
        BookingPolicies.durationFloor,
      );
      // #644: a booking ends on the day it starts, so nothing above a
      // full day could ever be accepted however large the stored value.
      expect(
        BookingPolicies.fromRules(const {'max_duration_minutes': 100000})
            .maxDurationMinutes,
        BookingPolicies.maxDurationCeiling,
      );
      expect(BookingPolicies.maxDurationCeiling, 24 * 60);
    });

    test('each key is read independently — one does not disturb another',
        () {
      final p = BookingPolicies.fromRules(const {
        'advance_horizon_days': 14,
        'min_duration_minutes': 60,
        'max_duration_minutes': 480,
      });
      expect(p.advanceHorizonDays, 14);
      expect(p.minDurationMinutes, 60);
      expect(p.maxDurationMinutes, 480);
      // and the unrelated policies keep their own defaults
      expect(p.allowPastBookings, isFalse);
      expect(p.simultaneousReservations, 1);
      expect(p.outsideHoursMode, OutsideHoursMode.charged);
    });
  });

  group('coherence', () {
    test('a minimum above the maximum is incoherent', () {
      expect(
        const BookingPolicies(minDurationMinutes: 240, maxDurationMinutes: 60)
            .durationsAreCoherent,
        isFalse,
        reason: 'the server compares each bound alone, so this refuses '
            'EVERY booking without ever explaining why',
      );
      expect(const BookingPolicies().durationsAreCoherent, isTrue);
      expect(
        const BookingPolicies(minDurationMinutes: 60, maxDurationMinutes: 60)
            .durationsAreCoherent,
        isTrue,
        reason: 'equal bounds accept exactly one duration, which is odd '
            'but not contradictory',
      );
    });
  });

  group('the server contract (migration 0122)', () {
    late String sql;

    setUpAll(() {
      sql = File('supabase/migrations/0122_enforcement_parity.sql')
          .readAsStringSync();
    });

    test('the client defaults ARE the server fallbacks', () {
      // enforce_booking_rules coalesces each key to these numbers; the
      // screen shows them for a workspace that stored nothing, so a
      // change on either side must break here.
      expect(
        sql,
        contains(
            "coalesce((rules->>'advance_horizon_days')::int, "
            '${BookingPolicies.defaultHorizonDays})'),
      );
      expect(
        sql,
        contains("coalesce((rules->>'min_duration_minutes')::int, "
            '${BookingPolicies.defaultMinDuration})'),
      );
      expect(
        sql,
        contains("coalesce((rules->>'max_duration_minutes')::int, "
            '${BookingPolicies.defaultMaxDuration})'),
      );
    });

    test('the keys the client writes are the keys the server reads', () {
      for (final key in [
        BookingPolicies.advanceHorizonDaysKey,
        BookingPolicies.minDurationMinutesKey,
        BookingPolicies.maxDurationMinutesKey,
      ]) {
        expect(sql, contains("rules->>'$key'"),
            reason: '$key must be the wire name the server reads');
      }
    });
  });
}
