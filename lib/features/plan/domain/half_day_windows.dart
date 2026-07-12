// SPDX-License-Identifier: MIT

/// A half-open booking window `[start, end)` in local wall-clock time.
typedef HalfDayWindow = ({DateTime start, DateTime end});

/// The three canonical half-day booking windows of a local day (#201,
/// epic #199): morning 00:00–13:00, afternoon 13:00–24:00 and full day
/// 00:00–24:00. "24:00" is next-day 00:00 — the end stays exclusive.
///
/// The 13:00 pivot is the billing halves' pivot (spec §7) and MUST match
/// `enforce_booking_rules` (migration 0025) and `member_statement`
/// (migration 0008) — pinned by test. Pure Dart: builders take any
/// instant of the local day and return that day's window; overflowing
/// day+1 lets `DateTime` normalize month/year ends and keeps the maths
/// DST-agnostic (wall-clock times, not fixed durations).
abstract final class HalfDayWindows {
  /// Local hour separating morning from afternoon (spec §7).
  static const int pivotHour = 13;

  /// Morning window of [day]'s local date: 00:00–13:00.
  static HalfDayWindow morning(DateTime day) {
    final local = day.toLocal();
    return (
      start: DateTime(local.year, local.month, local.day),
      end: DateTime(local.year, local.month, local.day, pivotHour),
    );
  }

  /// Afternoon window of [day]'s local date: 13:00 – next-day 00:00.
  static HalfDayWindow afternoon(DateTime day) {
    final local = day.toLocal();
    return (
      start: DateTime(local.year, local.month, local.day, pivotHour),
      end: DateTime(local.year, local.month, local.day + 1),
    );
  }

  /// Full-day window of [day]'s local date: 00:00 – next-day 00:00.
  static HalfDayWindow fullDay(DateTime day) {
    final local = day.toLocal();
    return (
      start: DateTime(local.year, local.month, local.day),
      end: DateTime(local.year, local.month, local.day + 1),
    );
  }

  /// The half-day window containing [now] (walk-up end derivation, #201):
  /// before 13:00 local the morning window (end 13:00), from 13:00 on the
  /// afternoon window (end next-day 00:00).
  static HalfDayWindow windowForNow(DateTime now) {
    final local = now.toLocal();
    return local.hour < pivotHour ? morning(local) : afternoon(local);
  }
}
