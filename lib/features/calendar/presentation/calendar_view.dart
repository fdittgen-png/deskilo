// SPDX-License-Identifier: 0BSD
import '../../../core/time/workspace_time.dart';

/// #818 — the three ways to look at the hub's feed. The view decides
/// the RANGE the feed asks for and how the arrows step; the feed itself
/// is the same one list of dated facts.
enum CalendarView { agenda, week, month }

/// How far the agenda looks ahead.
const int calendarAgendaDays = 30;

/// Pure range arithmetic for a view around an ANCHOR day (a
/// workspace-local date-only value). Nothing here reads a clock or a
/// provider, so a test can drive every view with plain dates.
class CalendarSelection {
  const CalendarSelection({required this.view, required this.anchor});

  final CalendarView view;
  final DateTime anchor;

  /// Monday of [anchor]'s ISO week.
  DateTime get weekStart =>
      DateTime(anchor.year, anchor.month, anchor.day - (anchor.weekday - 1));

  /// The first day the FEED loads.
  DateTime get from => switch (view) {
        CalendarView.agenda => anchor,
        CalendarView.week => weekStart,
        CalendarView.month => anchor,
      };

  /// The day AFTER the last one the feed loads (half-open).
  DateTime get to => switch (view) {
        CalendarView.agenda =>
          DateTime(anchor.year, anchor.month, anchor.day + calendarAgendaDays),
        CalendarView.week =>
          DateTime(weekStart.year, weekStart.month, weekStart.day + 7),
        CalendarView.month => DateTime(anchor.year, anchor.month, anchor.day + 1),
      };

  /// The month the grid draws — the feed's month view loads ONE day,
  /// but the markers need the whole month.
  DateTime get monthStart => DateTime(anchor.year, anchor.month);
  DateTime get monthEnd => DateTime(anchor.year, anchor.month + 1);

  /// The arrows: 30 days on the agenda, a week, a month.
  CalendarSelection shifted(int steps) => switch (view) {
        CalendarView.agenda => CalendarSelection(
            view: view,
            anchor: DateTime(anchor.year, anchor.month,
                anchor.day + steps * calendarAgendaDays),
          ),
        CalendarView.week => CalendarSelection(
            view: view,
            anchor: DateTime(anchor.year, anchor.month, anchor.day + 7 * steps),
          ),
        CalendarView.month => CalendarSelection(
            view: view,
            // Keep the day of month where the month has it, else its last.
            anchor: _sameDayInMonth(anchor, steps),
          ),
      };

  static DateTime _sameDayInMonth(DateTime day, int months) {
    final first = DateTime(day.year, day.month + months);
    final last = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, day.day > last ? last : day.day);
  }

  CalendarSelection withView(CalendarView next) =>
      CalendarSelection(view: next, anchor: anchor);

  CalendarSelection withAnchor(DateTime next) =>
      CalendarSelection(view: view, anchor: DateTime(next.year, next.month, next.day));

  /// Half-open UTC bounds of [from]..[to] on the workspace clock — what
  /// the query sends (#490).
  ({DateTime from, DateTime to}) utcBounds({DateTime? from, DateTime? to}) {
    final f = from ?? this.from;
    final t = to ?? this.to;
    return (
      from: WorkspaceTime.at(f.year, f.month, f.day).toUtc(),
      to: WorkspaceTime.at(t.year, t.month, t.day).toUtc(),
    );
  }
}

/// Today / Tomorrow / Yesterday, or null when the day deserves its date.
enum RelativeDay { today, tomorrow, yesterday }

RelativeDay? relativeDayOf(DateTime day, DateTime today) {
  final d = DateTime(day.year, day.month, day.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  return switch (d) {
    0 => RelativeDay.today,
    1 => RelativeDay.tomorrow,
    -1 => RelativeDay.yesterday,
    _ => null,
  };
}
