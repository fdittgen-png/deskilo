// SPDX-License-Identifier: MIT
import '../../../core/time/workspace_time.dart';

/// A half-open booking window `[start, end)`.
typedef HalfDayWindow = ({DateTime start, DateTime end});

/// The three canonical half-day booking windows of a day (#201, epic
/// #199): morning 00:00–13:00, afternoon 13:00–24:00 and full day
/// 00:00–24:00. "24:00" is next-day 00:00 — the end stays exclusive.
///
/// The 13:00 pivot is the billing halves' pivot (spec §7) and MUST match
/// `enforce_booking_rules` (migration 0025) and `member_statement`
/// (migration 0008) — pinned by test.
///
/// [day] carries the CALENDAR DATE the user picked (device-local pills);
/// the returned instants are that date's wall-clock hours on the
/// WORKSPACE clock ([WorkspaceTime]) — the server enforces canonical
/// windows in the workspace timezone, so a device hours away must still
/// send the workspace's midnights. Overflowing day+1 normalizes through
/// the constructors and keeps the maths DST-agnostic.
abstract final class HalfDayWindows {
  /// Workspace-local hour separating morning from afternoon (spec §7).
  static const int pivotHour = 13;

  /// Morning window of [day]'s date: 00:00–13:00.
  static HalfDayWindow morning(DateTime day) {
    final local = day.toLocal();
    return (
      start: WorkspaceTime.at(local.year, local.month, local.day),
      end: WorkspaceTime.at(local.year, local.month, local.day, pivotHour),
    );
  }

  /// Afternoon window of [day]'s date: 13:00 – next-day 00:00.
  static HalfDayWindow afternoon(DateTime day) {
    final local = day.toLocal();
    return (
      start: WorkspaceTime.at(local.year, local.month, local.day, pivotHour),
      end: WorkspaceTime.at(local.year, local.month, local.day + 1),
    );
  }

  /// Full-day window of [day]'s date: 00:00 – next-day 00:00.
  static HalfDayWindow fullDay(DateTime day) {
    final local = day.toLocal();
    return (
      start: WorkspaceTime.at(local.year, local.month, local.day),
      end: WorkspaceTime.at(local.year, local.month, local.day + 1),
    );
  }

  /// The half-day window containing [now] (walk-up end derivation, #201):
  /// before 13:00 workspace-local the morning window (end 13:00), from
  /// 13:00 on the afternoon window (end next-day 00:00). The containing
  /// day is the WORKSPACE-local date of [now] — near midnight it may
  /// differ from the device's.
  static HalfDayWindow windowForNow(DateTime now) {
    final wsDate = WorkspaceTime.dateOf(now);
    return WorkspaceTime.hourOf(now) < pivotHour
        ? morning(wsDate)
        : afternoon(wsDate);
  }
}
