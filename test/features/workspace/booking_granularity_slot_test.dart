// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2631 — a resource's own slot (seats.slot_minutes) maps to the same
// granularity the server's enforce_booking_rules applies: null keeps the
// workspace value, 5/15/30/60 a minute grid, 1440 the full day, anything
// else the workspace value.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookingGranularity.forSlot (#2631)', () {
    test('no slot keeps the workspace value for every granularity', () {
      for (final g in BookingGranularity.values) {
        expect(BookingGranularity.forSlot(null, g), g);
      }
    });

    test('a slot overrides the workspace value', () {
      const ws = BookingGranularity.halfDay;
      expect(BookingGranularity.forSlot(5, ws), BookingGranularity.minutes5);
      expect(BookingGranularity.forSlot(15, ws), BookingGranularity.minutes15);
      expect(BookingGranularity.forSlot(30, ws), BookingGranularity.minutes30);
      expect(BookingGranularity.forSlot(60, ws), BookingGranularity.minutes60);
      expect(BookingGranularity.forSlot(1440, ws), BookingGranularity.fullDay);
    });

    test('an unknown slot falls back to the workspace value', () {
      expect(
        BookingGranularity.forSlot(7, BookingGranularity.halfDay),
        BookingGranularity.halfDay,
      );
    });

    test('the server accepts exactly the slots the client maps', () {
      final sql = File('supabase/migrations/0441_resource_booking_slot.sql')
          .readAsStringSync();
      expect(sql, contains('slot_minutes in (5, 15, 30, 60, 1440)'));
    });
  });
}
