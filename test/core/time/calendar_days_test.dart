// SPDX-License-Identifier: 0BSD
//
// #1231 — money dates were computed with `Duration(days: n)`.
//
// A week containing a clock change is not 168 hours long. Subtracting
// seven days from 1 November in a zone that fell back in October lands
// at 23:00 on the 24th, not midnight on the 25th — and everything that
// then reads `.day` is off by one, twice a year.
//
// Two places that mattered: `subscriptionIssueDay`, which is when
// members see their subscription invoice, and an invoice's `dueOn`,
// which is printed on the document and starts the dunning clock.
import 'package:deskilo/core/time/calendar_days.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('addCalendarDays', () {
    test('crosses a month boundary backwards by the calendar', () {
      expect(
        addCalendarDays(DateTime(2026, 11), -7),
        DateTime(2026, 10, 25),
        reason: 'the Sunday Europe/Paris falls back — 25 hours long, and '
            'a Duration of 168 hours would land on the 24th',
      );
    });

    test('crosses a year boundary', () {
      expect(addCalendarDays(DateTime(2027, 1, 3), -7), DateTime(2026, 12, 27));
    });

    test('keeps the time of day, because a term of payment does', () {
      final issued = DateTime(2026, 3, 20, 14, 30);
      expect(addCalendarDays(issued, 30), DateTime(2026, 4, 19, 14, 30));
    });

    test('handles a spring-forward month, where a day is 23 hours', () {
      // Europe/Paris springs forward on 29 March 2026.
      expect(addCalendarDays(DateTime(2026, 3, 28), 3), DateTime(2026, 3, 31));
    });

    test('a leap day is a day like any other', () {
      expect(addCalendarDays(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
      expect(addCalendarDays(DateTime(2027, 2, 28), 1), DateTime(2027, 3));
    });
  });

  group('calendarDaysBetween', () {
    test('counts calendar days, not elapsed hours', () {
      expect(
        calendarDaysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)),
        2,
        reason: 'that span contains a 25-hour day; inDays would say 2 only '
            'by luck and 1 when the hours fall the other way',
      );
    });

    test('the same day is zero, and the direction is signed', () {
      expect(calendarDaysBetween(DateTime(2026, 5, 4), DateTime(2026, 5, 4)), 0);
      expect(
          calendarDaysBetween(DateTime(2026, 5, 6), DateTime(2026, 5, 4)), -2);
    });

    test('ignores the time of day — a term is counted in days', () {
      expect(
        calendarDaysBetween(
          DateTime(2026, 5, 4, 23, 59),
          DateTime(2026, 5, 5, 0, 1),
        ),
        1,
        reason: 'two minutes apart, but one day apart on a calendar, and a '
            'payment term is a calendar promise',
      );
    });
  });
}
