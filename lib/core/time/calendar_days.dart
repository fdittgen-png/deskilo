// SPDX-License-Identifier: AGPL-3.0-or-later

/// Adding DAYS to a date, the way a calendar does it (#1231).
///
/// `date.add(Duration(days: 7))` adds 168 hours, and a week containing a
/// clock change is not 168 hours long. In Europe/Paris the last Sunday
/// in October has 25, so `DateTime(2026, 11, 1).subtract(const
/// Duration(days: 7))` lands at **23:00 on 24 October** rather than
/// midnight on the 25th — and anything that then reads `.day` is off by
/// one, twice a year, for half the world.
///
/// That is a nuisance in a scheduler and a defect on a document: the
/// dates this is used for are a subscription's issue day and an
/// invoice's payment term, both of which get printed and one of which
/// starts a dunning clock.
///
/// Dart's `DateTime` constructor normalises out-of-range components
/// using calendar arithmetic — `DateTime(2026, 11, 1 - 7)` IS 25 October
/// — so the fix is to go through the constructor and never through a
/// `Duration`. Time of day is preserved, which is what a term of
/// payment means: thirty days from this moment, at this moment.
DateTime addCalendarDays(DateTime date, int days) => DateTime(
      date.year,
      date.month,
      date.day + days,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );

/// Whole days between two dates, counted as CALENDAR days.
///
/// `to.difference(from).inDays` truncates elapsed hours, so a span
/// containing a clock change reports one day fewer (or more) than a
/// calendar says. A term of payment that reads "3 days left" on a
/// Saturday and "3 days left" again on the Sunday is this bug.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  // Both are local midnights, so the difference is a whole number of
  // days plus at most an hour of DST; rounding recovers the day count.
  return (b.difference(a).inHours / 24).round();
}
