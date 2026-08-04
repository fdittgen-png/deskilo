// SPDX-License-Identifier: 0BSD
//
// #201/#446: the canonical half-day windows the plan header offers
// under half-day granularity are the configured WORKING DAY (WorkHours,
// defaults 8:00 / 12:00 / 17:00). The bounds are a cross-system
// contract — enforce_booking_rules and the billing halves of
// member_statement / assert_member_quota (migration 0087) read the
// same booking_rules keys with the same defaults — so both the keys
// and the default values are pinned here against the migration file.
import 'dart:io';

import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(WorkHours.reset);

  group('WorkHours (#446)', () {
    test('pins the default working day: 8:00–17:00, boundary 12:00, '
        'half day 4h, full day 8h', () {
      expect(WorkHours.defaults.startMinutes, 8 * 60);
      expect(WorkHours.defaults.halfBoundaryMinutes, 12 * 60);
      expect(WorkHours.defaults.endMinutes, 17 * 60);
      expect(WorkHours.defaults.halfDayHours, 4);
      expect(WorkHours.defaults.fullDayHours, 8);
    });

    test('pins the booking_rules keys (server contract)', () {
      expect(WorkHours.keyStart, 'work_start_minutes');
      expect(WorkHours.keyBoundary, 'half_boundary_minutes');
      expect(WorkHours.keyEnd, 'work_end_minutes');
      expect(WorkHours.keyHalfDayHours, 'half_day_hours');
      expect(WorkHours.keyFullDayHours, 'full_day_hours');
    });

    test('fromRules reads the keys and round-trips through toRules', () {
      final hours = WorkHours.fromRules(const {
        'work_start_minutes': 540,
        'half_boundary_minutes': 780,
        'work_end_minutes': 1080,
        'half_day_hours': 5,
        'full_day_hours': 9,
      });
      expect(hours.startMinutes, 540);
      expect(hours.halfBoundaryMinutes, 780);
      expect(hours.endMinutes, 1080);
      expect(WorkHours.fromRules(hours.toRules()), hours);
    });

    test('absent keys mean the defaults; an inconsistent triple falls '
        'back entirely (like the 0087 constraint)', () {
      expect(WorkHours.fromRules(const {}), WorkHours.defaults);
      expect(
        WorkHours.fromRules(const {
          'work_start_minutes': 900, // start after boundary — invalid
          'half_boundary_minutes': 720,
        }),
        WorkHours.defaults,
      );
    });
  });

  group('HalfDayWindows (#201/#446)', () {
    test('morning covers 08:00–12:00 of the local day by default', () {
      final w = HalfDayWindows.morning(DateTime(2026, 7, 15, 9, 42));
      expect(w.start, DateTime(2026, 7, 15, 8));
      expect(w.end, DateTime(2026, 7, 15, 12));
    });

    test('afternoon covers 12:00–17:00 by default', () {
      final w = HalfDayWindows.afternoon(DateTime(2026, 7, 15, 9, 42));
      expect(w.start, DateTime(2026, 7, 15, 12));
      expect(w.end, DateTime(2026, 7, 15, 17));
    });

    test('full day covers 08:00–17:00 by default', () {
      final w = HalfDayWindows.fullDay(DateTime(2026, 7, 15, 23, 59));
      expect(w.start, DateTime(2026, 7, 15, 8));
      expect(w.end, DateTime(2026, 7, 15, 17));
    });

    test('the windows follow an installed working day', () {
      WorkHours.install(const WorkHours(
        startMinutes: 9 * 60 + 30,
        halfBoundaryMinutes: 13 * 60,
        endMinutes: 18 * 60,
        halfDayHours: 4,
        fullDayHours: 8,
      ));
      final w = HalfDayWindows.morning(DateTime(2026, 7, 15));
      expect(w.start, DateTime(2026, 7, 15, 9, 30));
      expect(w.end, DateTime(2026, 7, 15, 13));
      expect(HalfDayWindows.fullDay(DateTime(2026, 7, 15)).end,
          DateTime(2026, 7, 15, 18));
    });

    test('a midnight work end lands on next-day 00:00 (normalized)', () {
      WorkHours.install(const WorkHours(
        startMinutes: 0,
        halfBoundaryMinutes: 13 * 60,
        endMinutes: 24 * 60,
        halfDayHours: 6,
        fullDayHours: 12,
      ));
      final w = HalfDayWindows.afternoon(DateTime(2026, 12, 31, 14));
      expect(w.start, DateTime(2026, 12, 31, 13));
      expect(w.end, DateTime(2027, 1, 1));
    });

    test(
        'windows are wall-clock (DST-agnostic): the EU spring-forward day '
        'still pivots at the local boundary', () {
      // 2026-03-29 is the EU DST switch; a duration-based implementation
      // would drift by an hour there. Wall-clock construction cannot.
      final w = HalfDayWindows.morning(DateTime(2026, 3, 29, 8));
      expect(w.end, DateTime(2026, 3, 29, 12));
    });

    test('windowForNow: before the boundary → the morning half', () {
      final w = HalfDayWindows.windowForNow(DateTime(2026, 7, 15, 11, 59));
      expect(w.start, DateTime(2026, 7, 15, 8));
      expect(w.end, DateTime(2026, 7, 15, 12));
    });

    test('windowForNow: boundary to work end → the afternoon half', () {
      final atBoundary =
          HalfDayWindows.windowForNow(DateTime(2026, 7, 15, 12));
      expect(atBoundary.start, DateTime(2026, 7, 15, 12));
      expect(atBoundary.end, DateTime(2026, 7, 15, 17));
    });

    test('windowForNow: after the working day → overtime until local '
        'midnight (the 0087 late walk-up allowance)', () {
      final late = HalfDayWindows.windowForNow(DateTime(2026, 7, 15, 19));
      expect(late.start, DateTime(2026, 7, 15, 17));
      expect(late.end, DateTime(2026, 7, 16));
    });

    test('early morning (before work start) still books the morning half',
        () {
      final w = HalfDayWindows.windowForNow(DateTime(2026, 7, 15, 6, 30));
      expect(w.end, DateTime(2026, 7, 15, 12));
    });
  });

  group('server contract (migration 0087)', () {
    final sql =
        File('supabase/migrations/0087_working_hours.sql').readAsStringSync();

    test('enforce_booking_rules reads the same keys with the same defaults',
        () {
      expect(sql,
          contains("(rules->>'${WorkHours.keyStart}')::int, "
              '${WorkHours.defaults.startMinutes}'));
      expect(sql,
          contains("(rules->>'${WorkHours.keyBoundary}')::int, "
              '${WorkHours.defaults.halfBoundaryMinutes}'));
      expect(sql,
          contains("(rules->>'${WorkHours.keyEnd}')::int, "
              '${WorkHours.defaults.endMinutes}'));
    });

    test('member_statement and assert_member_quota bill on the same '
        'boundary and half-day-hours defaults', () {
      expect(
        RegExp("\\(v_rules->>'${WorkHours.keyBoundary}'\\)::int, "
                '${WorkHours.defaults.halfBoundaryMinutes}')
            .allMatches(sql)
            .length,
        2, // member_statement v8 + assert_member_quota v3
      );
      expect(
        RegExp("\\(v_rules->>'${WorkHours.keyHalfDayHours}'\\)::int, "
                '${WorkHours.defaults.halfDayHours}')
            .allMatches(sql)
            .length,
        2,
      );
    });

    test("the 'hours' granularity passes no grid branch but converts to "
        'half-day equivalents', () {
      expect(sql, contains("if v_gran = 'hours' then"));
      expect(sql, contains('least(2, greatest(1,'));
    });
  });
}
