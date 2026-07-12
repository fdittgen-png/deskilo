// SPDX-License-Identifier: MIT
import 'dart:io';

import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  group('BookingGranularity (#200)', () {
    test('pins the wire values (persisted in booking_rules — append only)',
        () {
      expect(BookingGranularity.flexible.wireName, 'flexible');
      expect(BookingGranularity.halfDay.wireName, 'half_day');
      expect(BookingGranularity.values, hasLength(2));
    });

    test('fromWire falls back to flexible for null / unknown values', () {
      expect(BookingGranularity.fromWire('flexible'),
          BookingGranularity.flexible);
      expect(
          BookingGranularity.fromWire('half_day'), BookingGranularity.halfDay);
      expect(BookingGranularity.fromWire(null), BookingGranularity.flexible);
      expect(BookingGranularity.fromWire(''), BookingGranularity.flexible);
      expect(BookingGranularity.fromWire('quarter_day'),
          BookingGranularity.flexible);
    });

    test('pins the booking_rules jsonb key', () {
      expect(BookingRulesKeys.granularity, 'granularity');
    });

    test('pins the server rejection substring', () {
      expect(BookingGranularityError.serverSubstring, 'half-day');
    });

    test('migration 0025 enforces the same key, wire value and message', () {
      final sql = File('supabase/migrations/0025_booking_granularity.sql')
          .readAsStringSync();
      // The jsonb key and the half_day wire value gate the check.
      expect(
        sql,
        contains("rules->>'${BookingRulesKeys.granularity}' = "
            "'${BookingGranularity.halfDay.wireName}'"),
      );
      // The raise message carries the substring the client error mapping
      // matches (#201).
      expect(
        sql,
        contains("raise exception 'bookings must cover a "
            "${BookingGranularityError.serverSubstring} "
            "(00:00-13:00, 13:00-24:00) or the full day'"),
      );
    });
  });

  group('FakeWorkspaceRepository booking granularity (#200)', () {
    test('round-trips and defaults to flexible when unseeded', () async {
      final repo = FakeWorkspaceRepository.withWorkspace();
      expect(await repo.fetchBookingGranularity('ws-1'),
          BookingGranularity.flexible);

      await repo.setBookingGranularity('ws-1', BookingGranularity.halfDay);
      expect(await repo.fetchBookingGranularity('ws-1'),
          BookingGranularity.halfDay);

      await repo.setBookingGranularity('ws-1', BookingGranularity.flexible);
      expect(await repo.fetchBookingGranularity('ws-1'),
          BookingGranularity.flexible);
    });

    test('writing the granularity preserves the open weekdays (merge!)',
        () async {
      final repo = FakeWorkspaceRepository.withWorkspace()
        ..openWeekdays['ws-1'] = [1, 3, 5];

      await repo.setBookingGranularity('ws-1', BookingGranularity.halfDay);

      expect(await repo.fetchOpenWeekdays('ws-1'), [1, 3, 5]);
      expect(await repo.fetchBookingGranularity('ws-1'),
          BookingGranularity.halfDay);

      // And the other direction: weekday writes keep the granularity.
      await repo.setOpenWeekdays('ws-1', [2, 4]);
      expect(await repo.fetchBookingGranularity('ws-1'),
          BookingGranularity.halfDay);
    });
  });
}
