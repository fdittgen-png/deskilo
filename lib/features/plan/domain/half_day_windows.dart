// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/time/work_hours.dart';
import '../../../core/time/workspace_time.dart';

/// A half-open booking window `[start, end)`.
typedef HalfDayWindow = ({DateTime start, DateTime end});

/// The three canonical half-day booking windows of a day (#201, epic
/// #199), built from the workspace's configured working day (#446,
/// [WorkHours] — defaults 8:00–17:00 with the boundary at 12:00):
/// morning start–boundary, afternoon boundary–end and full day
/// start–end.
///
/// The bounds MUST match `enforce_booking_rules` and `member_statement`
/// (migration 0087) — pinned by test.
///
/// [day] carries the CALENDAR DATE the user picked (device-local pills);
/// it is read as a date, never converted (#3659): an instant goes through
/// `WorkspaceTime.dateOf` first, so the business's day is the one booked;
/// the returned instants are that date's wall-clock hours on the
/// WORKSPACE clock ([WorkspaceTime]) — the server enforces canonical
/// windows in the workspace timezone, so a device hours away must still
/// send the workspace's wall-clock bounds. Overflowing day+1 normalizes
/// through the constructors and keeps the maths DST-agnostic.
abstract final class HalfDayWindows {
  static DateTime _at(DateTime local, int minutes) => WorkspaceTime.at(
      local.year, local.month, local.day, minutes ~/ 60, minutes % 60);

  /// Morning window of [day]'s date: work start – half boundary.
  static HalfDayWindow morning(DateTime day) {
    final local = day;
    final hours = WorkHours.current;
    return (
      start: _at(local, hours.startMinutes),
      end: _at(local, hours.halfBoundaryMinutes),
    );
  }

  /// Afternoon window of [day]'s date: half boundary – work end.
  static HalfDayWindow afternoon(DateTime day) {
    final local = day;
    final hours = WorkHours.current;
    return (
      start: _at(local, hours.halfBoundaryMinutes),
      end: _at(local, hours.endMinutes),
    );
  }

  /// Full-day window of [day]'s date: work start – work end.
  static HalfDayWindow fullDay(DateTime day) {
    final local = day;
    final hours = WorkHours.current;
    return (
      start: _at(local, hours.startMinutes),
      end: _at(local, hours.endMinutes),
    );
  }

  /// #3659 — the morning, afternoon and full day of the business's day at
  /// [instant], never the device's.
  static HalfDayWindow morningAt(DateTime instant) =>
      morning(WorkspaceTime.dateOf(instant));
  static HalfDayWindow afternoonAt(DateTime instant) =>
      afternoon(WorkspaceTime.dateOf(instant));
  static HalfDayWindow fullDayAt(DateTime instant) =>
      fullDay(WorkspaceTime.dateOf(instant));

  /// Occupancy DISPLAY halves (#446): the week grid paints a booking in
  /// whichever half of the CALENDAR day it touches, so these split at
  /// midnight → boundary → midnight — an early booking outside working
  /// hours still shows in the AM half. Booking always uses the
  /// canonical windows above.
  static HalfDayWindow displayMorning(DateTime day) {
    final local = day;
    return (
      start: WorkspaceTime.at(local.year, local.month, local.day),
      end: _at(local, WorkHours.current.halfBoundaryMinutes),
    );
  }

  /// Boundary → next local midnight; see [displayMorning].
  static HalfDayWindow displayAfternoon(DateTime day) {
    final local = day;
    return (
      start: _at(local, WorkHours.current.halfBoundaryMinutes),
      end: WorkspaceTime.at(local.year, local.month, local.day + 1),
    );
  }

  /// The half-day window containing [now] (walk-up end derivation,
  /// #201): before the boundary the morning window, before work end the
  /// afternoon window. AT or AFTER work end an overtime window running
  /// to the next local midnight — a late walk-up must still get a
  /// bookable end, and the server allows exactly that midnight end. The
  /// containing day is the WORKSPACE-local date of [now] — near
  /// midnight it may differ from the device's.
  static HalfDayWindow windowForNow(DateTime now) {
    final hours = WorkHours.current;
    final minutes = WorkspaceTime.minutesOfDay(now);
    final wsDate = WorkspaceTime.dateOf(now);
    if (minutes < hours.halfBoundaryMinutes) return morning(wsDate);
    if (minutes < hours.endMinutes) return afternoon(wsDate);
    return (
      start: _at(wsDate, hours.endMinutes),
      end: WorkspaceTime.at(wsDate.year, wsDate.month, wsDate.day + 1),
    );
  }
}
