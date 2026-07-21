// SPDX-License-Identifier: 0BSD
import '../../plan/domain/half_day_windows.dart';

import '../../../core/time/workspace_time.dart';

/// What a booking range IS, for display: a full-day booking must read
/// "Full day", never the meaningless "00:00 – 00:00" a naive time
/// format makes of a midnight-to-midnight range (field screenshots) —
/// and the canonical halves get their names too.
enum BookingWindowKind { morning, afternoon, fullDay, times }

/// Classifies `[start, end)` against the canonical windows of its own
/// workspace-local day; anything non-canonical is plain [times].
BookingWindowKind bookingWindowKindOf(DateTime start, DateTime end) {
  final day = WorkspaceTime.dateOf(start);
  bool matches(HalfDayWindow w) =>
      start.isAtSameMomentAs(w.start) && end.isAtSameMomentAs(w.end);
  if (matches(HalfDayWindows.fullDay(day))) return BookingWindowKind.fullDay;
  if (matches(HalfDayWindows.morning(day))) return BookingWindowKind.morning;
  if (matches(HalfDayWindows.afternoon(day))) {
    return BookingWindowKind.afternoon;
  }
  return BookingWindowKind.times;
}
