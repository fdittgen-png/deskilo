// SPDX-License-Identifier: AGPL-3.0-or-later
import 'closure_day.dart';

/// The next day this workspace is open, at or after [from] (#1196).
///
/// The screenshot batch was shot on a Sunday. What a member got was a
/// *Closed on this day* banner with no action, every seat painted
/// blocked, and inert day-part chips — a screen that states a fact and
/// offers nothing. Opening on today is right; leaving the member to
/// work out for themselves that the way forward is the date chip and
/// two taps is not.
///
/// [openWeekdays] are ISO weekdays (1 = Monday … 7 = Sunday) and
/// [closures] are the whole-day closures on top of them, so this is the
/// same rule the calendar paints its open days with.
///
/// Returns null when there is no open day within [within] — a workspace
/// that has closed for a fortnight, or one whose open weekdays are
/// empty. A banner with nothing to point at says only what it always
/// said, which is the honest answer.
DateTime? nextOpenDay(
  DateTime from, {
  required List<int> openWeekdays,
  required List<ClosureDay> closures,
  Duration within = const Duration(days: 60),
}) {
  if (openWeekdays.isEmpty) return null;
  final closed = {
    for (final c in closures) _key(c.day.year, c.day.month, c.day.day),
  };
  var day = DateTime(from.year, from.month, from.day);
  final limit = day.add(within);
  while (!day.isAfter(limit)) {
    if (openWeekdays.contains(day.weekday) &&
        !closed.contains(_key(day.year, day.month, day.day))) {
      return day;
    }
    // Plain arithmetic on a date-only value, deliberately: adding a
    // Duration across a DST boundary lands at 23:00 the day before.
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return null;
}

int _key(int year, int month, int day) => year * 10000 + month * 100 + day;
