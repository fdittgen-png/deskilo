// SPDX-License-Identifier: 0BSD
import '../../../core/time/work_hours.dart';
import '../../../core/time/workspace_time.dart';
import '../../plan/domain/seat.dart';
import '../../workspace/domain/booking_granularity.dart';
import '../../workspace/domain/booking_policies.dart';
import '../../workspace/domain/closure_day.dart';
import '../../workspace/domain/workspace_availability.dart';

/// #814 — why the server WOULD refuse a window, known before asking.
///
/// One value per refusal of `enforce_booking_rules` v9 (migration 0122)
/// plus the two seat-level facts a surface already holds (closed day,
/// blocked seat). Ordered like the chokepoint checks them, so a surface
/// names the same reason the server would.
enum BookingRefusal {
  /// `assert_workspace_open` — weekday not open or a closure day.
  closedDay,

  /// The seat carries a maintenance block over the window (#161).
  seatBlocked,

  /// `beyond the advance-booking horizon of N days`.
  beyondHorizon,

  /// `below the minimum duration of N minutes`.
  tooShort,

  /// `above the maximum duration of N minutes`.
  tooLong,

  /// `the booking lies entirely in the past` (allow_past_bookings off).
  past,

  /// `a walk-up check-in must start today`.
  walkUpNotToday,

  /// `a booking must end on the day it starts` (#644).
  crossesMidnight,

  /// Outside-hours mode `off`: the window leaves the working day.
  outsideHoursOff,

  /// Outside-hours mode `walkup_only`: booking AHEAD outside the hours.
  outsideHoursAheadOnly,
}

/// Everything the gate needs, read once from the workspace's
/// availability parameters. Pure data: the same input serves the plan
/// tap, the booking sheet, the kiosk, the scan sheet and the tests.
class BookingGate {
  const BookingGate({
    required this.openWeekdays,
    required this.closures,
    required this.policies,
    required this.granularity,
    required this.hours,
    required this.now,
  });

  final List<int> openWeekdays;
  final List<ClosureDay> closures;
  final BookingPolicies policies;
  final BookingGranularity granularity;
  final WorkHours hours;

  /// The real clock (never a browsed instant).
  final DateTime now;

  /// Whether the workspace is open on the workspace-local day of [at].
  bool dayOpen(DateTime at) =>
      isWorkspaceOpenOn(WorkspaceTime.dateOf(at), openWeekdays, closures);

  DateTime _atMinutes(DateTime day, int minutes) => WorkspaceTime.at(
        day.year,
        day.month,
        day.day,
        minutes ~/ 60,
        minutes % 60,
      );

  /// The chokepoint's answer for `[start, end)`, or null when it would
  /// pass. [walkUp] is the server's `p_walk_up` — a check-in that means
  /// "I am here now". Granularity SHAPES (half-day edges, grid ticks)
  /// are not judged here: every surface already derives its windows
  /// from the shape, so the shape can only be broken by a stale screen
  /// the server still catches.
  BookingRefusal? refusalFor({
    required DateTime start,
    required DateTime end,
    required bool walkUp,
    Seat? seat,
  }) {
    if (!dayOpen(start)) return BookingRefusal.closedDay;
    if (seat != null && seat.isBlockedAt(start)) {
      return BookingRefusal.seatBlocked;
    }
    if (start.isAfter(now.add(Duration(days: policies.advanceHorizonDays)))) {
      return BookingRefusal.beyondHorizon;
    }
    final minutes = end.difference(start).inMinutes;
    if (minutes < policies.minDurationMinutes) return BookingRefusal.tooShort;
    if (minutes > policies.maxDurationMinutes) return BookingRefusal.tooLong;
    // Day-level, like the server: the booking's LAST day already ended.
    final lastDay =
        WorkspaceTime.dateOf(end.subtract(const Duration(seconds: 1)));
    final today = WorkspaceTime.dateOf(now);
    if (lastDay.isBefore(today) && !policies.allowPastBookings) {
      return BookingRefusal.past;
    }
    if (walkUp && WorkspaceTime.dateOf(start) != today) {
      return BookingRefusal.walkUpNotToday;
    }
    final day = WorkspaceTime.dateOf(start);
    final midnight = WorkspaceTime.at(day.year, day.month, day.day + 1);
    if (end.isAfter(midnight)) return BookingRefusal.crossesMidnight;
    final touchesOutside = start.isBefore(_atMinutes(day, hours.startMinutes)) ||
        end.isAfter(_atMinutes(day, hours.endMinutes));
    if (touchesOutside) {
      switch (policies.outsideHoursMode) {
        case OutsideHoursMode.off:
          return BookingRefusal.outsideHoursOff;
        case OutsideHoursMode.walkupOnly:
          if (!walkUp) return BookingRefusal.outsideHoursAheadOnly;
        case OutsideHoursMode.free:
        case OutsideHoursMode.charged:
          break;
      }
    }
    return null;
  }

  /// The server substring [refusal] corresponds to — the wire contract
  /// `bookingErrorText` recognizes. Pinned by test against the
  /// migration so client and server can never drift apart silently.
  static String serverSubstringOf(BookingRefusal refusal) => switch (refusal) {
        BookingRefusal.closedDay => WorkspaceClosedError.serverSubstring,
        BookingRefusal.seatBlocked => 'seat is blocked',
        BookingRefusal.beyondHorizon => 'beyond the advance-booking horizon',
        BookingRefusal.tooShort => 'below the minimum duration',
        BookingRefusal.tooLong => 'above the maximum duration',
        BookingRefusal.past => 'lies entirely in the past',
        BookingRefusal.walkUpNotToday => 'must start today',
        BookingRefusal.crossesMidnight => 'must end on the day it starts',
        BookingRefusal.outsideHoursOff => 'outside the opening hours',
        BookingRefusal.outsideHoursAheadOnly => 'spontaneous check-in',
      };
}
