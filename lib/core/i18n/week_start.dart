// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:intl/intl.dart';

import 'app_format.dart';
import 'format_prefs.dart';

/// #3648 — THE week-start boundary: the day a week starts on, for every
/// calendar grid, strip and date picker, as an ISO weekday (`DateTime.weekday`:
/// Monday 1 .. Sunday 7).
///
/// The format locale starts the week where its own calendar does (Sunday in
/// `en_US`, Monday in `de_DE`, Saturday in `ar_EG`); a chosen day
/// ([WeekStartPref]: a person's, else the business's) overrides it. No screen
/// does weekday arithmetic of its own: the week's first day, a day's column
/// and the header names all come from here.
///
/// This is a DISPLAY preference. Weekly recurrence and ISO week numbers in
/// the database are Monday-based whatever it says.
int weekStartOf(AppFormat format) =>
    format.weekStart.isoWeekday ?? _localeWeekStart(format.locale);

/// The ISO weekday [locale]'s calendar starts its week on. `intl` counts from
/// Monday = 0 (`FIRSTDAYOFWEEK`); `MaterialLocalizations.firstDayOfWeekIndex`
/// counts from Sunday = 0; `DateTime.weekday` from Monday = 1. This is the one
/// place those three are reconciled.
int _localeWeekStart(String locale) {
  try {
    return DateFormat.d(locale).dateSymbols.FIRSTDAYOFWEEK % 7 + 1;
  } on Object {
    // A locale `intl` has no symbols for reads as the platform default (ISO).
    return DateTime.monday;
  }
}

/// The ISO weekday of [day]'s column in a week starting on [weekStart]:
/// 0 for the first column .. 6 for the last.
int weekColumnOf(DateTime day, int weekStart) =>
    (day.weekday - weekStart + 7) % 7;

/// The first day (date only) of the week [day] belongs to.
DateTime startOfWeek(DateTime day, int weekStart) =>
    DateTime(day.year, day.month, day.day - weekColumnOf(day, weekStart));

/// One column header: the locale's NARROW name (`EEEEE`) to draw, and the
/// full name for assistive technology (two days share an initial in most
/// languages).
typedef WeekdayHeader = ({String narrow, String full});

/// The seven headers of a week in [format], first column first.
List<WeekdayHeader> weekdayHeaders(AppFormat format) {
  final first = weekStartOf(format);
  final narrow = DateFormat('EEEEE', format.locale);
  final full = DateFormat.EEEE(format.locale);
  return [
    for (var i = 0; i < 7; i++)
      // 2024-01-01 is a Monday, so the day of month is the ISO weekday.
      (
        narrow: narrow.format(DateTime(2024, 1, (first - 1 + i) % 7 + 1)),
        full: full.format(DateTime(2024, 1, (first - 1 + i) % 7 + 1)),
      ),
  ];
}
