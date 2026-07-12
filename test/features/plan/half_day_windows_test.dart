// SPDX-License-Identifier: MIT
//
// #201: the canonical half-day windows the plan header offers under
// half-day granularity. The 13:00 pivot is a cross-system contract —
// enforce_booking_rules (migration 0025) and the billing halves of
// member_statement (migration 0008) use the same boundary — so it is
// pinned here against both migration files.
import 'dart:io';

import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HalfDayWindows (#201)', () {
    test('pins the 13:00 pivot', () {
      expect(HalfDayWindows.pivotHour, 13);
    });

    test('morning covers 00:00–13:00 of the local day', () {
      final w = HalfDayWindows.morning(DateTime(2026, 7, 15, 9, 42));
      expect(w.start, DateTime(2026, 7, 15));
      expect(w.end, DateTime(2026, 7, 15, 13));
    });

    test('afternoon covers 13:00 – next-day 00:00', () {
      final w = HalfDayWindows.afternoon(DateTime(2026, 7, 15, 9, 42));
      expect(w.start, DateTime(2026, 7, 15, 13));
      expect(w.end, DateTime(2026, 7, 16));
    });

    test('full day covers 00:00 – next-day 00:00', () {
      final w = HalfDayWindows.fullDay(DateTime(2026, 7, 15, 23, 59));
      expect(w.start, DateTime(2026, 7, 15));
      expect(w.end, DateTime(2026, 7, 16));
    });

    test('windows normalize month and year ends', () {
      final dec31 = HalfDayWindows.afternoon(DateTime(2026, 12, 31, 14));
      expect(dec31.end, DateTime(2027, 1, 1));
      final jan31 = HalfDayWindows.fullDay(DateTime(2027, 1, 31));
      expect(jan31.end, DateTime(2027, 2, 1));
    });

    test(
        'windows are wall-clock (DST-agnostic): the EU spring-forward day '
        'still pivots at local 13:00', () {
      // 2026-03-29 is the EU DST switch; a duration-based implementation
      // would land on 14:00 there. Wall-clock construction cannot.
      final w = HalfDayWindows.morning(DateTime(2026, 3, 29, 8));
      expect(w.end, DateTime(2026, 3, 29, 13));
      expect(w.end.hour, HalfDayWindows.pivotHour);
    });

    test('windowForNow: before 13:00 → morning half ending 13:00', () {
      final w = HalfDayWindows.windowForNow(DateTime(2026, 7, 15, 12, 59));
      expect(w.start, DateTime(2026, 7, 15));
      expect(w.end, DateTime(2026, 7, 15, 13));
    });

    test('windowForNow: from 13:00 → afternoon half ending next-day 00:00',
        () {
      final atPivot = HalfDayWindows.windowForNow(DateTime(2026, 7, 15, 13));
      expect(atPivot.start, DateTime(2026, 7, 15, 13));
      expect(atPivot.end, DateTime(2026, 7, 16));

      final late = HalfDayWindows.windowForNow(DateTime(2026, 7, 15, 23, 59));
      expect(late.end, DateTime(2026, 7, 16));
    });

    test('migration 0025 enforces the same pivot (server contract)', () {
      final sql = File('supabase/migrations/0025_booking_granularity.sql')
          .readAsStringSync();
      expect(sql, contains("time '${HalfDayWindows.pivotHour}:00'"));
    });

    test('member_statement bills with the same pivot (migration 0008)', () {
      final sql = File('supabase/migrations/0008_plans_ledger_payments.sql')
          .readAsStringSync();
      expect(
        sql,
        contains('< ${HalfDayWindows.pivotHour} then 0 else 1'),
      );
    });
  });
}
