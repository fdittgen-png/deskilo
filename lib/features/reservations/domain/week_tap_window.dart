// SPDX-License-Identifier: 0BSD
import '../../../core/time/workspace_time.dart';
import '../../workspace/domain/booking_granularity.dart';
import '../../plan/domain/half_day_windows.dart';

/// The window a Week-cell tap books (#7/#236), lifted out of
/// reserve_screen.dart when it reached its length budget.
///
/// Pure window arithmetic, so it does not belong in a screen at all:
/// nothing here reads state, watches a provider or touches a widget. It
/// takes what it needs and answers.
///
/// Three granularities, three different answers, and the middle one is
/// the trap: under FULL-DAY the tapped half is IGNORED, because a
/// workspace that books by the day has no morning and afternoon to
/// choose between and honouring the tap would create a half-day booking
/// its own rules forbid.
HalfDayWindow weekTapWindow({
  required DateTime day,
  required bool morning,
  required BookingGranularity granularity,
  /// The hub's current from->to, mapped onto [day] under flexible
  /// granularity — the tap inherits the window the member already chose
  /// rather than inventing one.
  required HalfDayWindow current,
  required DateTime Function(DateTime from) defaultEndFor,
}) {
  if (granularity == BookingGranularity.halfDay) {
    return morning ? HalfDayWindows.morning(day) : HalfDayWindows.afternoon(day);
  }
  if (granularity == BookingGranularity.fullDay) {
    return HalfDayWindows.fullDay(day);
  }
  final startWall = WorkspaceTime.wall(current.start);
  final endWall = WorkspaceTime.wall(current.end);
  final from = WorkspaceTime.at(
    day.year,
    day.month,
    day.day,
    startWall.hour,
    startWall.minute,
  );
  var to = WorkspaceTime.at(
    day.year,
    day.month,
    day.day,
    endWall.hour,
    endWall.minute,
  );
  // A window that ends at or before it starts is not a booking. It
  // happens when the current window's times fall outside the tapped
  // day's opening hours.
  if (!to.isAfter(from)) to = defaultEndFor(from);
  return (start: from, end: to);
}
