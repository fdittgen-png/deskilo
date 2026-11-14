// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — what the reservation detail sheet's buttons do, and how far a
// booking may still be extended or shortened; the sheet decides which show.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/trace/act_trace.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/adaptive/task_surface.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../application/change_reservation.dart';
import '../../domain/booking_error_text.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_repository.dart';
import 'reservation_detail_sheet.dart';
import 'reservation_edit_pickers.dart';
import 'reservation_time_picker.dart';
import 'series_result_dialog.dart';

/// The actions of one booking's detail sheet ([ReservationDetailSheet]).
class ReservationDetailActions {
  const ReservationDetailActions(
    this.reservation, {
    required this.readGranularity,
    required this.seriesAllowed,
    required this.refresh,
    required this.repository,
    this.inPane = false,
    this.onRefused,
  });

  final Reservation reservation;

  /// The workspace's booking granularity, read when an action runs.
  final BookingGranularity? Function() readGranularity;

  /// Whether series booking is on, read when the times are edited.
  final bool Function() seriesAllowed;

  /// The plan and lists behind the sheet are stale after a change.
  final void Function() refresh;

  /// The bookings, resolved by the sheet when an action runs.
  final ReservationRepository Function() repository;

  /// #3843 — the actions stand in a pane beside the calendar, not in a
  /// sheet: nothing closes after them, and cancel asks as a short task.
  final bool inPane;

  /// #3843 — where a refusal is said (the pane); else a snack.
  final void Function(String refusal)? onRefused;

  /// Closes the sheet after an action; a pane stays.
  void _close(BuildContext context) {
    if (!inPane) Navigator.of(context).pop();
  }

  void _refused(BuildContext context, String refusal) {
    final say = onRefused;
    say == null ? AppSnack.error(context, refusal) : say(refusal);
  }

  /// The question before an action: a phone sheet, or a short task.
  Future<T?> _ask<T>(BuildContext context, WidgetBuilder builder) => inPane
      ? showTask<T>(context, size: TaskSize.short, builder: builder)
      : showAppSheet<T>(context: context, builder: builder);

  BookingGranularity get _granularity =>
      readGranularity() ?? BookingGranularity.flexible;

  /// #492 — the request dialog, then the sheet closes (#2328: the plan's
  /// seat sheet files the same request through [requestBookingDeletion]).
  Future<void> requestDeletion(BuildContext context, WidgetRef ref) async {
    if (!await requestBookingDeletion(context, ref, reservation)) return;
    if (context.mounted) _close(context);
  }

  // ── cancel ──

  /// Same choice flow as the calendar's menu (#118): a single booking
  /// offers one cancel action; a series adds "this and following".
  Future<void> cancel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final r = reservation;
    final choice = await _ask<CancelScope>(
      context,
      (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey(
                'reservation-detail-sheet-plan-cancel-reservation-button',
              ),
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(
                r.seriesId == null
                    ? (l10n.planCancelReservationButton)
                    : (l10n.calendarCancelOccurrence),
              ),
              onTap: () => Navigator.of(sheetContext).pop(CancelScope.thisOne),
            ),
            if (r.seriesId != null)
              ListTile(
                key: const ValueKey(
                  'reservation-detail-sheet-calendar-cancel-following',
                ),
                leading: const Icon(Icons.fast_forward_outlined),
                title: Text(l10n.calendarCancelFollowing),
                onTap: () =>
                    Navigator.of(sheetContext)
                        .pop(CancelScope.thisAndFollowing),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    try {
      // #1234 — which occurrences a cancellation touches is a decision,
      // and it lives in application/ where a test can reach it.
      await cancelReservation(repository(), r, scope: choice);
    } on Object catch (e, st) {
      debugPrint('cancel failed: $e\n$st');
      TraceLogger.instance.error(
        'reservations',
        'reservation cancel failed server=${ActTrace.serverAnswer(e)}',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      _refused(context, l10n.workspaceGenericError);
      return;
    }
    refresh();
    if (!context.mounted) return;
    _close(context);
    AppSnack.success(context, l10n.reservationCancelledSnack);
  }

  // ── edit ──

  /// Granularity-aware window edit on the booking's own (workspace) day:
  /// half-day offers the three canonical windows, minute grids and
  /// legacy flexible offer snapped from/to pickers, full-day re-books
  /// the full day (nothing else exists to pick).
  Future<void> editTimes(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final r = reservation;
    final granularity = _granularity;
    final day = WorkspaceTime.dateOf(r.startsAt);

    HalfDayWindow? window;
    if (granularity == BookingGranularity.halfDay) {
      window = await pickHalfDayWindow(context, l10n, day);
    } else if (granularity == BookingGranularity.fullDay) {
      window = HalfDayWindows.fullDay(day);
    } else {
      window = await pickReservationTimes(
        context,
        l10n,
        reservation,
        snap: granularity.stepMinutes ?? 15,
        snapMinutesOfDay: granularity.snapMinutesOfDay,
      );
    }
    if (window == null || !context.mounted) return;

    // Repetition on modification too: a single booking may become a
    // series here. Only offered when the workspace enables series and
    // this isn't already a series instance (changing a series' pattern
    // is out of scope — cancel + rebook for that).
    final canRepeat = r.seriesId == null && seriesAllowed();
    SeriesPattern? pattern;
    if (canRepeat) {
      pattern = await pickSeriesPattern(context, l10n);
      if (!context.mounted) return;
    }

    final RescheduleOutcome outcome;
    try {
      // #1394 — with a pattern this is `convert_to_series` (0224): ONE
      // transaction that refuses rather than leaving the member with the
      // original cancelled and nothing in its place. It used to be a
      // client-side `cancel` followed by `createSeries`, and when no date
      // could be booked the second returned NORMALLY with an empty
      // `booked`, so nothing here ever caught it.
      outcome = await rescheduleReservation(
        repository(),
        r,
        start: window.start,
        end: window.end,
        pattern: pattern,
        // The horizon the booking sheet starts from. The member cannot
        // change it HERE yet — the detail sheet has no repeat-end
        // affordance, and adding one is its own slice (#1394).
        until: pattern == null
            ? null
            : window.start.add(const Duration(days: 28)),
      );
    } on Object catch (e, st) {
      debugPrint('reservation edit failed: $e\n$st');
      TraceLogger.instance.error(
        'reservations',
        'reservation edit failed server=${ActTrace.serverAnswer(e)}',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      // #574 — the server's own reason (granularity, one-place, quota),
      // not a generic "taken": the edit flow used to swallow it.
      _refused(
        context,
        bookingErrorText(
          l10n,
          e,
          l10n.reserveBookingFailed,
          stepMinutes: granularity.stepMinutes,
        ),
      );
      return;
    }
    refresh();
    if (!context.mounted) return;
    _close(context);
    // A repeat may book some dates and skip others, and the skips are
    // what the member needs to see — a generic "updated" would hide
    // them. The plain move has nothing to report beyond success.
    switch (outcome) {
      case BecameSeries(:final result):
        await showSeriesResultDialog(context, result);
      case Moved():
        AppSnack.success(context, l10n.reservationUpdatedSnack);
    }
  }

  /// The next canonical LATER end for a running booking (#574), or null
  /// when nothing later exists: under half-day granularity a morning
  /// grows to the day's end; grids/hours/flexible may pick any later
  /// time; a booking already at its day's end has nowhere to grow.
  DateTime? laterEndFor(Reservation r) {
    final granularity = _granularity;
    final day = WorkspaceTime.dateOf(r.startsAt);
    final dayEnd = HalfDayWindows.fullDay(day).end;
    if (granularity == BookingGranularity.halfDay ||
        granularity == BookingGranularity.fullDay) {
      return r.endsAt.isBefore(dayEnd) ? dayEnd : null;
    }
    // Grids, hours, flexible: anything later the same day works — the
    // picker decides; the day's midnight bounds it.
    final next = day.add(const Duration(days: 1));
    final midnight = WorkspaceTime.at(next.year, next.month, next.day);
    return r.endsAt.isBefore(midnight) ? midnight : null;
  }

  /// The canonical EARLIER end a running booking may shrink to (#638),
  /// or null when nothing earlier is reachable. Day-based granularity
  /// has exactly one earlier canonical edge — the half-day boundary —
  /// and it only counts while it still lies ahead of [now] (and after
  /// the immovable start). Grids/hours/flexible let the picker choose:
  /// they qualify as soon as one whole step still fits between now and
  /// the current end.
  DateTime? earlierEndFor(Reservation r, DateTime now) {
    final granularity = _granularity;
    final day = WorkspaceTime.dateOf(r.startsAt);
    if (granularity.isDayBased) {
      final boundary = HalfDayWindows.morning(day).end;
      return boundary.isBefore(r.endsAt) &&
              boundary.isAfter(now) &&
              boundary.isAfter(r.startsAt)
          ? boundary
          : null;
    }
    // The picker decides; one grid step ahead of now is the earliest
    // end that can still be reached.
    final step = granularity.stepMinutes ?? 15;
    final earliest = now.add(Duration(minutes: step));
    return earliest.isBefore(r.endsAt) ? earliest : null;
  }

  /// One snapped instant on [day] from a clock pick — the SHARED grid
  /// rule ([BookingGranularity.snapMinutesOfDay], #638), so extend and
  /// shrink can never drift apart the way they had.
  DateTime _snappedOnDay(
    DateTime day,
    TimeOfDay picked,
    BookingGranularity granularity,
  ) {
    final minutes = granularity.snapMinutesOfDay(
      picked.hour * 60 + picked.minute,
    );
    return WorkspaceTime.at(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: minutes.clamp(0, 24 * 60)));
  }

  /// #574 — extend a RUNNING booking's end within the workspace's
  /// granularity. Day-based: one confirm to the day's end (that IS the
  /// only later canonical edge). Grids/hours: a snapped time picker.
  Future<void> extendEnd(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final r = reservation;
    final granularity = _granularity;
    final day = WorkspaceTime.dateOf(r.startsAt);

    DateTime? newEnd;
    if (granularity.isDayBased) {
      newEnd = HalfDayWindows.fullDay(day).end;
    } else {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(appFormatOf(context).wall(r.endsAt)),
      );
      if (picked == null || !context.mounted) return;
      newEnd = _snappedOnDay(day, picked, granularity);
    }
    if (!newEnd.isAfter(r.endsAt)) {
      if (!context.mounted) return;
      AppSnack.info(context, l10n.reservationExtendLaterOnly);
      return;
    }
    await _writeEnd(context, ref, newEnd, granularity);
  }

  /// #638 — free the rest of the booking: shrink a RUNNING booking's end
  /// to an earlier canonical edge, the start untouched (the server keeps
  /// it immovable anyway). Day-based granularity offers the half-day
  /// boundary — "cancel the rest of the day", the affordance the guide
  /// already described; grids/hours offer a snapped picker that refuses
  /// anything not still ahead of now.
  Future<void> endEarly(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final r = reservation;
    final granularity = _granularity;
    final now = ref.read(clockProvider).now();
    final day = WorkspaceTime.dateOf(r.startsAt);

    DateTime newEnd;
    if (granularity.isDayBased) {
      final boundary = earlierEndFor(r, now);
      if (boundary == null) return; // the button is not offered then
      newEnd = boundary;
    } else {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(appFormatOf(context).wall(r.endsAt)),
      );
      if (picked == null || !context.mounted) return;
      newEnd = _snappedOnDay(day, picked, granularity);
    }
    // Ahead of now AND before the current end — the two halves of the
    // server's own rule, refused here with the reason instead of a
    // round-trip that says "invalid".
    if (!newEnd.isBefore(r.endsAt) || !newEnd.isAfter(now)) {
      if (!context.mounted) return;
      AppSnack.info(context, l10n.reservationEndEarlyAheadOnly);
      return;
    }
    await _writeEnd(context, ref, newEnd, granularity);
  }

  /// The one write both end changes share (#638): the start is passed
  /// back untouched, refusals go through [bookingErrorText] like every
  /// neighbouring action, success pops the sheet.
  Future<void> _writeEnd(
    BuildContext context,
    WidgetRef ref,
    DateTime newEnd,
    BookingGranularity granularity,
  ) async {
    final l10n = context.l10n;
    final r = reservation;
    try {
      // #1234 — "I am leaving at a different time", never "I arrived at
      // a different time": the command keeps the start out of the
      // caller's hands, which is the rule update_reservation enforces.
      await changeReservationEnd(repository(), r, end: newEnd);
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'reservations',
        'reservation end change failed server=${ActTrace.serverAnswer(e)}',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      _refused(
        context,
        bookingErrorText(
          l10n,
          e,
          l10n.reserveBookingFailed,
          stepMinutes: granularity.stepMinutes,
        ),
      );
      return;
    }
    refresh();
    if (!context.mounted) return;
    _close(context);
    AppSnack.success(context, l10n.reservationUpdatedSnack);
  }
}
