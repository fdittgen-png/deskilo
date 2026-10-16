// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Reserve hub's window arithmetic (#184, #201, #586, #908), lifted out of
// the screen's State (#2494): which window is browsed, where the day's last
// slot is, how a start snaps to the configured step, what a day change does
// to a hand-picked window. Pure — dates and a granularity in, dates out.














import '../../../../core/time/workspace_time.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../domain/default_booking_period.dart';
import '../../domain/walk_up_window.dart';
import 'reserve_hub_metrics.dart';




class ReserveWindowRules {
  const ReserveWindowRules(this.granularity);

  final BookingGranularity granularity;

  /// One configured slot — the minimal booking extension.
  Duration get slotStep => Duration(
        minutes: granularity.stepMinutes ?? ReserveHubMetrics.snapMinutes,
      );

  /// The day's last selectable slot: 23:45 of [day], on the WORKSPACE clock
  /// (#490).
  DateTime lastSlotOf(DateTime day) => WorkspaceTime.at(
        day.year,
        day.month,
        day.day,
        ReserveHubMetrics.lastSlotHour,
        ReserveHubMetrics.lastSlotMinute,
      );

  /// Snaps [t] down to the previous slot of the workspace's configured step
  /// (#184 pattern; 0032 makes the step owner-configurable).
  DateTime snapToSlot(DateTime t) {
    final local = WorkspaceTime.wall(t);
    final snap = granularity.stepMinutes ?? ReserveHubMetrics.snapMinutes;
    final m = (local.hour * 60 + local.minute) ~/ snap * snap;
    return WorkspaceTime.at(
        local.year, local.month, local.day, m ~/ 60, m % 60);
  }

  /// Default window end for a start at [from]: the default stay, clamped to
  /// the day's last slot — and never at/before [from].
  DateTime defaultEndFor(DateTime from) {
    var end = from.add(ReserveHubMetrics.defaultStay);
    final last = lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) end = from.add(slotStep);
    return end;
  }

  /// [end] kept for a window of [duration] starting at [from]: capped to the
  /// day's last slot, never at/before [from].
  DateTime endAfter(DateTime from, Duration duration) {
    var end = from.add(duration);
    final last = lastSlotOf(from);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(from)) end = from.add(slotStep);
    return end;
  }

  /// The window the hub currently browses/books on [selectedDay]. An
  /// explicit choice ([start] and [end]) wins; otherwise half-day
  /// granularity defaults to the member's preferred period (#586, full day
  /// when none is set) and flexible to "now"-anchored times of day.
  HalfDayWindow effectiveWindow({
    required DateTime selectedDay,
    required DateTime now,
    required DefaultBookingPeriod? preferredPeriod,
    DateTime? start,
    DateTime? end,
  }) {
    if (start != null && end != null) return (start: start, end: end);
    if (granularity.isDayBased) {
      return defaultWindowFor(preferredPeriod, selectedDay);
    }
    final snapped = snapToSlot(now);
    final from = WorkspaceTime.at(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      snapped.hour,
      snapped.minute,
    );
    return (start: from, end: defaultEndFor(from));
  }

  /// #2631 — the window a resource with its own slot ([slotMinutes],
  /// `seats.slot_minutes`) is booked in, given the window [asked] for under
  /// the workspace's granularity. The workspace's own value (null or a slot
  /// that resolves to it) changes nothing.
  ///
  /// A full-day slot is the whole day. A minute grid snaps the start onto its
  /// grid and lasts at least one slot; where the workspace books by half-day
  /// the asked window is a midnight half, so the booking starts at the
  /// opening of [day] (or at the next slot when it is today) instead.
  HalfDayWindow resourceWindow(
    int? slotMinutes, {
    required HalfDayWindow asked,
    required DateTime now,
    required HalfDayWindow day,
  }) {
    final own = BookingGranularity.forSlot(slotMinutes, granularity);
    if (own == granularity) return asked;
    if (own == BookingGranularity.fullDay) {
      return HalfDayWindows.fullDay(asked.start);
    }
    final step = Duration(minutes: own.stepMinutes ?? 60);
    final grid = ReserveWindowRules(own);
    if (granularity.isDayBased && _isCanonical(asked)) {
      final today = WorkspaceTime.dateOf(now) == WorkspaceTime.dateOf(day.start);
      var from = grid.snapToSlot(today && now.isAfter(day.start) ? now : day.start);
      if (from.isBefore(day.start) || (today && from.isBefore(now))) {
        from = from.add(step);
      }
      return (start: from, end: from.add(step));
    }
    final from = grid.snapToSlot(asked.start);
    final slots = (asked.end.difference(from).inMinutes / step.inMinutes).ceil();
    return (start: from, end: from.add(step * (slots < 1 ? 1 : slots)));
  }

  /// The morning, the afternoon or the full day of the asked window's day.
  static bool _isCanonical(HalfDayWindow w) => [
        HalfDayWindows.morning,
        HalfDayWindows.afternoon,
        HalfDayWindows.fullDay,
      ].any((build) {
        final c = build(w.start);
        return c.start == w.start && c.end == w.end;
      });

  /// A walk-up's end (#687): the current stint under half-day granularity
  /// (the whole day for a member whose default period is the day, #586), the
  /// working day under the full-day and hourly grids, the default stay on a
  /// minute grid — and the slot itself for a resource with its own.
  DateTime walkUpEnd(
    HalfDayWindow window, {
    required DefaultBookingPeriod? period,
    required bool ownSlot,
  }) {
    if (ownSlot) return window.end;
    final fullDay = HalfDayWindows.fullDay(window.start).end;
    return switch (granularity) {
      BookingGranularity.halfDay =>
        period == DefaultBookingPeriod.fullDay && fullDay.isAfter(window.start)
            ? fullDay
            : HalfDayWindows.windowForNow(window.start).end,
      BookingGranularity.fullDay ||
      BookingGranularity.hours =>
        walkUpWindow(granularity, window.start).end,
      _ => defaultEndFor(window.start),
    };
  }

  /// A hand-picked [window] on [fromDay], re-mapped onto [toDay]: the
  /// canonical half re-derived under half-day granularity, times of day kept
  /// under flexible (plan's date-button behaviour, #184/#201).
  HalfDayWindow remapWindow(
    HalfDayWindow window, {
    required DateTime fromDay,
    required DateTime toDay,
  }) {
    if (granularity.isDayBased) {
      final builder =
          _matchingHalfDayBuilder(fromDay, window) ?? HalfDayWindows.fullDay;
      return builder(toDay);
    }
    final from = WorkspaceTime.at(
      toDay.year,
      toDay.month,
      toDay.day,
      window.start.hour,
      window.start.minute,
    );
    var kept = WorkspaceTime.at(
      toDay.year,
      toDay.month,
      toDay.day,
      window.end.hour,
      window.end.minute,
    );
    if (!kept.isAfter(from)) kept = defaultEndFor(from);
    return (start: from, end: kept);
  }

  /// The canonical builder whose window on [day] [window] matches — null
  /// when none does (#201 pattern).
  static HalfDayWindow Function(DateTime day)? _matchingHalfDayBuilder(
    DateTime day,
    HalfDayWindow window,
  ) {
    const builders = [
      HalfDayWindows.morning,
      HalfDayWindows.afternoon,
      HalfDayWindows.fullDay,
    ];
    for (final builder in builders) {
      final candidate = builder(day);
      if (window.start == candidate.start && window.end == candidate.end) {
        return builder;
      }
    }
    return null;
  }
}
