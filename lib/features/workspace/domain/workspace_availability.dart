// SPDX-License-Identifier: MIT
//
// Pure closed-day derivation (#186) — the client-side twin of the
// `assert_workspace_open` guard (migration 0013): a day is open when its
// ISO weekday is in the workspace's open weekdays AND no one-off closure
// day falls on it. The plan uses it to stop rendering bookable seats on
// days the server would reject anyway.
import 'closure_day.dart';

/// Server-side error text raised by `assert_workspace_open`
/// (migration 0013) when a booking touches a closed day. Two variants
/// exist — `workspace is closed on <day> (weekday not open)` and
/// `workspace is closed on <day> (closure day)` — sharing this prefix,
/// which the booking error mapping matches (#186). Pinned by test.
abstract final class WorkspaceClosedError {
  static const String serverSubstring = 'workspace is closed';
}

/// Whether the workspace is open on the calendar day of [localDay] (#186).
///
/// [localDay] is a workspace-local wall-clock instant — any time on the
/// day counts, only its date component matters. The plan browses local
/// wall-clock days (see `dayKeyOf`), matching the server's
/// workspace-timezone day walk for co-located users. [openWeekdays] are
/// ISO weekdays (1=Mon..7=Sun, like [DateTime.weekday]); [closures] are
/// date-only local midnights (#127).
bool isWorkspaceOpenOn(
  DateTime localDay,
  List<int> openWeekdays,
  List<ClosureDay> closures,
) {
  if (!openWeekdays.contains(localDay.weekday)) return false;
  return !closures.any((c) =>
      c.day.year == localDay.year &&
      c.day.month == localDay.month &&
      c.day.day == localDay.day);
}
