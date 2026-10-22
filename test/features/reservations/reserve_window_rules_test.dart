// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 / #2603 -- the Reserve hub's window arithmetic as tables on
// ReserveWindowRules (no taps): which window is browsed, how a start snaps,
// where a default stay ends, what a walk-up books and what a day change
// does to a hand-picked window. The hub's widget tests keep the wiring.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/default_booking_period.dart';
import 'package:deskilo/features/reservations/presentation/screens/reserve_window_rules.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int day, int h, [int m = 0]) =>
    WorkspaceTime.at(2026, 5, day, h, m);

void main() {
  const flexible = ReserveWindowRules(BookingGranularity.flexible);
  const halfDay = ReserveWindowRules(BookingGranularity.halfDay);
  final today = _at(13, 0);
  final tomorrow = _at(14, 0);

  group('a start snaps down to the 15-minute step', () {
    final table = <String, (DateTime, DateTime)>{
      'on the step stays': (_at(13, 9), _at(13, 9)),
      'inside a step falls back': (_at(13, 9, 14), _at(13, 9)),
      'the last minute of a step': (_at(13, 10, 59), _at(13, 10, 45)),
    };
    for (final MapEntry(key: name, value: (t, snapped)) in table.entries) {
      test(name, () => expect(flexible.snapToSlot(t), snapped));
    }
  });

  group('a default stay ends four hours later, inside the day', () {
    final table = <String, (DateTime, DateTime)>{
      'mid-morning': (_at(13, 9), _at(13, 13)),
      'clamped to the last slot': (_at(13, 21), _at(13, 23, 45)),
      'never at its own start': (
        _at(13, 23, 45),
        _at(13, 23, 45).add(const Duration(minutes: 15)),
      ),
    };
    for (final MapEntry(key: name, value: (from, end)) in table.entries) {
      test(name, () => expect(flexible.defaultEndFor(from), end));
    }
  });

  group('the browsed window', () {
    test('an explicit choice wins', () {
      final w = halfDay.effectiveWindow(
        selectedDay: today,
        now: _at(13, 10),
        preferredPeriod: DefaultBookingPeriod.morning,
        start: _at(13, 14),
        end: _at(13, 16),
      );
      expect((w.start, w.end), (_at(13, 14), _at(13, 16)));
    });
    final periods = <String, (DefaultBookingPeriod?, HalfDayWindow)>{
      'half day: the preferred morning': (
        DefaultBookingPeriod.morning,
        HalfDayWindows.morning(tomorrow),
      ),
      'half day: the preferred afternoon': (
        DefaultBookingPeriod.afternoon,
        HalfDayWindows.afternoon(tomorrow),
      ),
      'half day: the full day when none is set': (
        null,
        HalfDayWindows.fullDay(tomorrow),
      ),
    };
    for (final MapEntry(key: name, value: (period, expected))
        in periods.entries) {
      test(name, () {
        final w = halfDay.effectiveWindow(
          selectedDay: tomorrow,
          now: _at(13, 10),
          preferredPeriod: period,
        );
        expect((w.start, w.end), (expected.start, expected.end));
      });
    }
    test('flexible: now, snapped, carried onto the browsed day', () {
      final w = flexible.effectiveWindow(
        selectedDay: tomorrow,
        now: _at(13, 10, 7),
        preferredPeriod: null,
      );
      expect((w.start, w.end), (_at(14, 10), _at(14, 14)));
    });
  });

  group('what a walk-up books', () {
    final morning = HalfDayWindows.morning(today);
    test('half day: the current stint', () {
      expect(
        halfDay.walkUpEnd(morning, period: null, ownSlot: false),
        HalfDayWindows.windowForNow(morning.start).end,
      );
    });
    test('half day, a member whose period is the day: the whole day', () {
      expect(
        halfDay.walkUpEnd(
          morning,
          period: DefaultBookingPeriod.fullDay,
          ownSlot: false,
        ),
        HalfDayWindows.fullDay(today).end,
      );
    });
    test('a minute grid: the default stay', () {
      final w = (start: _at(13, 9), end: _at(13, 10));
      expect(flexible.walkUpEnd(w, period: null, ownSlot: false), _at(13, 13));
    });
    test('a resource with its own slot: that slot', () {
      final w = (start: _at(13, 9), end: _at(13, 10));
      expect(flexible.walkUpEnd(w, period: null, ownSlot: true), _at(13, 10));
    });
  });

  group('a day change keeps the choice', () {
    test('half day: the same half on the new day', () {
      final w = halfDay.remapWindow(
        HalfDayWindows.afternoon(today),
        fromDay: today,
        toDay: tomorrow,
      );
      final expected = HalfDayWindows.afternoon(tomorrow);
      expect((w.start, w.end), (expected.start, expected.end));
    });
    test('half day: an unknown window becomes the full day', () {
      final w = halfDay.remapWindow(
        (start: _at(13, 9), end: _at(13, 10)),
        fromDay: today,
        toDay: tomorrow,
      );
      final expected = HalfDayWindows.fullDay(tomorrow);
      expect((w.start, w.end), (expected.start, expected.end));
    });
    test('flexible: the same times of day', () {
      final w = flexible.remapWindow(
        (start: _at(13, 9), end: _at(13, 11)),
        fromDay: today,
        toDay: tomorrow,
      );
      expect((w.start, w.end), (_at(14, 9), _at(14, 11)));
    });
  });
}
