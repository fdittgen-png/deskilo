// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../domain/booking_error_text.dart';
import '../../../plan/domain/seat_context.dart';
import '../../../plan/presentation/widgets/seat_accessory_row.dart';
import '../../../plan/providers/plan_focus_controller.dart';
import '../../../plan/providers/seat_context_providers.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_repository.dart';
import 'booking_range_text.dart';
import 'series_result_dialog.dart';
import '../../providers/reservation_providers.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/time/clock.dart';

/// Where is my reserved seat — and what can I do about it? (#182, edit
/// pass) Time range and status icon, the resolved location chain, the
/// seat's accessories, a "Show on plan" jump — and for MY still-upcoming
/// bookings the two actions that were missing on most surfaces: **edit
/// the window** (granularity-aware) and **cancel** (with the series
/// occurrence/following choice). One sheet serves the hub's plan, Day,
/// Week, and the calendar timeline, so every surface gains them at once.
///
/// Pops with the resolved [SeatContext] when the user wants the jump —
/// the caller then signals the plan tab and navigates.
class ReservationDetailSheet extends ConsumerWidget {
  const ReservationDetailSheet({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final r = reservation;
    final seatId = r.seatId;
    final officeId = r.officeId;
    // Self-loading like SeatAccessoryRow: while resolving (or when the
    // target vanished) the location line is simply absent and the jump
    // button disabled — the sheet itself never blocks.
    final targetAsync = seatId != null
        ? ref.watch(seatContextProvider(seatId))
        : officeId != null
            ? ref.watch(officeContextProvider(officeId))
            : const AsyncData<SeatContext?>(null);
    final target = targetAsync.value;

    final myMemberId = ref.watch(myMemberProvider).value?.id;
    // The actions belong to the owner of a still-upcoming booking; a
    // PAST or already CHECKED-IN one is never deleted directly (#492) —
    // deleting it becomes a REQUEST an owner/admin validates (was the
    // check-in forgotten, or was the booking unused?).
    final now = ref.read(clockProvider).now();
    final mine = r.memberId == myMemberId;
    final started = !r.startsAt.isAfter(now);
    final editable =
        mine && r.status == ReservationStatus.reserved && !started;
    // #574 — a RUNNING booking may still grow: sitting in the morning
    // seat and staying the day extends the end to a later canonical
    // edge (the server keeps the start immovable).
    final extendable = mine &&
        r.status == ReservationStatus.checkedIn &&
        r.endsAt.isAfter(now) &&
        _laterEndFor(ref, r) != null;
    // #638 — and a RUNNING booking may also SHRINK: `update_reservation`
    // v2 accepts an earlier canonical end ahead of now, but the client
    // only ever offered "later", so "cancel the rest of the day" was
    // documented and impossible.
    final endEarlyable = mine &&
        r.status == ReservationStatus.checkedIn &&
        r.endsAt.isAfter(now) &&
        _earlierEndFor(ref, r, now) != null;
    final deletionRequestable = mine &&
        !editable &&
        ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.deletionRequests) &&
        (r.status == ReservationStatus.checkedIn ||
            r.status == ReservationStatus.completed ||
            (r.status == ReservationStatus.reserved && started));

    return SafeArea(
      // Scrollable: with the action row the sheet can outgrow small
      // viewports (the #232 fixed-column lesson).
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                r.seriesId != null
                    ? Icons.repeat
                    : (r.status == ReservationStatus.checkedIn
                        ? Icons.event_seat
                        : Icons.schedule),
              ),
              // Date + the range as humans read it — a full day says
              // 'Full day', never '00:00 – 00:00' (field report).
              title: Text(
                '${DateFormat.MMMEd().format(WorkspaceTime.display(r.startsAt))}'
                ' · ${bookingRangeText(l10n, r.startsAt, r.endsAt)}',
              ),
              subtitle: target == null &&
                      r.seriesId == null &&
                      r.levelId == null &&
                      r.deskId == null &&
                      r.spaceLabel == null
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (target != null) Text(target.locationLine),
                        // #587 — the target was deleted: show the audit
                        // substitution snapshot instead of nothing.
                        if (target == null &&
                            r.seatId == null &&
                            r.deskId == null &&
                            r.officeId == null &&
                            r.levelId == null &&
                            r.spaceLabel != null)
                          Text(
                            r.spaceLabel!,
                            key: const ValueKey('reservation-substitution'),
                          ),
                        // Whole-desk booking (0059): name the table.
                        if (r.deskId != null)
                          Consumer(
                            builder: (context, ref, _) {
                              final name = ref
                                  .watch(targetNamesProvider)
                                  .value?[r.deskId];
                              return Text(
                                '${l10n?.deskDetail ?? 'Whole desk'}'
                                '${name == null ? '' : ' — $name'}',
                                key: const ValueKey('reservation-desk'),
                              );
                            },
                          ),
                        // Whole-level booking (0050): name the floor.
                        if (r.levelId != null)
                          Consumer(
                            builder: (context, ref, _) {
                              final name = ref
                                  .watch(levelsProvider)
                                  .value
                                  ?.where((l) => l.id == r.levelId)
                                  .firstOrNull
                                  ?.name;
                              return Text(
                                '${l10n?.levelDetail ?? 'Whole level'}'
                                '${name == null ? '' : ' — $name'}',
                                key: const ValueKey('reservation-level'),
                              );
                            },
                          ),
                        // The repetition modality (field report: it was
                        // invisible everywhere).
                        if (r.seriesId != null)
                          Text(
                            repeatLabelText(l10n, r.seriesPattern),
                            key: const ValueKey('reservation-repeat'),
                          ),
                      ],
                    ),
            ),
            if (seatId != null) SeatAccessoryRow(seatId: seatId),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.map_outlined),
              onPressed: target == null
                  ? null
                  : () => Navigator.of(context).pop(target),
              label: Text(l10n?.calendarShowOnPlan ?? 'Show on plan'),
            ),
            if (editable) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('reservation-edit'),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      onPressed: () => _editTimes(context, ref),
                      label: Text(
                        l10n?.reservationEditTimes ?? 'Edit times',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('reservation-cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error,
                      ),
                      icon: const Icon(Icons.event_busy_outlined),
                      onPressed: () => _cancel(context, ref),
                      label: Text(
                        l10n?.planCancelReservationButton ??
                            'Cancel reservation',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (extendable) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('reservation-extend'),
                icon: const Icon(Icons.more_time_outlined),
                onPressed: () => _extendEnd(context, ref),
                label: Text(
                  l10n?.reservationExtendButton ?? 'Stay longer',
                ),
              ),
            ],
            if (endEarlyable) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('reservation-end-early'),
                icon: const Icon(Icons.timelapse_outlined),
                onPressed: () => _endEarly(context, ref),
                label: Text(
                  l10n?.reservationEndEarlyButton ?? 'End earlier',
                ),
              ),
            ],
            if (deletionRequestable) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('reservation-delete-request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _requestDeletion(context, ref),
                // The label says REQUEST — nothing is deleted here.
                label: Text(l10n?.reservationDeleteRequestButton ??
                    'Request deletion'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// #492 — the request dialog: explains that an owner/admin validates
  /// (forgotten check-in vs unused booking), takes an optional reason,
  /// and files the pending event.
  Future<void> _requestDeletion(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.reservationDeleteRequestButton ??
            'Request deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n?.reservationDeleteRequestExplain ??
                'Past or checked-in bookings are not deleted directly. '
                    'An owner or admin will decide: was the check-in '
                    'simply forgotten (the booking stays), or was it '
                    'never used (it is removed)?'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('reservation-delete-reason'),
              controller: reasonController,
              maxLength: 300,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n?.reservationDeleteReasonLabel ??
                    'Reason (optional)',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('reservation-delete-submit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.reservationDeleteSubmit ??
                'Send request'),
          ),
        ],
      ),
    );
    final reason = reasonController.text;
    if (confirmed != true || !context.mounted) return;
    if (!await runGuarded(
      context,
      domain: 'reservations',
      message: 'reservation deletion request failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(eventRepositoryProvider)
          .requestReservationDeletion(reservation.id, reason: reason),
    )) {
      return;
    }
    invalidateBookingData(ref);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      l10n?.reservationDeleteSubmitted ??
          'Deletion requested — an owner or admin will decide.',
    );
  }

  // ── cancel ──

  /// Same choice flow as the calendar's menu (#118): a single booking
  /// offers one cancel action; a series adds "this and following".
  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final r = reservation;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(
                r.seriesId == null
                    ? (l10n?.planCancelReservationButton ??
                        'Cancel reservation')
                    : (l10n?.calendarCancelOccurrence ??
                        'Cancel this occurrence'),
              ),
              onTap: () => Navigator.of(sheetContext).pop('single'),
            ),
            if (r.seriesId != null)
              ListTile(
                leading: const Icon(Icons.fast_forward_outlined),
                title: Text(
                  l10n?.calendarCancelFollowing ??
                      'Cancel this and following',
                ),
                onTap: () => Navigator.of(sheetContext).pop('following'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    try {
      if (choice == 'single') {
        await ref.read(reservationRepositoryProvider).cancel(r.id);
      } else {
        await ref
            .read(reservationRepositoryProvider)
            .cancelSeries(r.seriesId!, from: r.startsAt);
      }
    } catch (e, st) {
      debugPrint('cancel failed: $e\n$st');
      TraceLogger.instance.error(
          'reservations', 'reservation cancel failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    invalidateBookingData(ref);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      l10n?.reservationCancelledSnack ?? 'Reservation cancelled.',
    );
  }

  // ── edit ──

  /// Granularity-aware window edit on the booking's own (workspace) day:
  /// half-day offers the three canonical windows, minute grids and
  /// legacy flexible offer snapped from/to pickers, full-day re-books
  /// the full day (nothing else exists to pick).
  Future<void> _editTimes(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final r = reservation;
    final granularity = ref.read(bookingGranularityProvider).value ??
        BookingGranularity.flexible;
    final day = WorkspaceTime.dateOf(r.startsAt);

    HalfDayWindow? window;
    if (granularity == BookingGranularity.halfDay) {
      window = await _pickHalfDayWindow(context, l10n, day);
    } else if (granularity == BookingGranularity.fullDay) {
      window = HalfDayWindows.fullDay(day);
    } else {
      window = await _pickTimes(context, l10n, granularity);
    }
    if (window == null || !context.mounted) return;

    // Repetition on modification too: a single booking may become a
    // series here. Only offered when the workspace enables series and
    // this isn't already a series instance (changing a series' pattern
    // is out of scope — cancel + rebook for that).
    final canRepeat = r.seriesId == null &&
        ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.seriesBooking);
    SeriesPattern? pattern;
    if (canRepeat) {
      pattern = await _pickPattern(context, l10n);
      if (!context.mounted) return;
    }

    if (pattern != null) {
      await _convertToSeries(context, ref, window, pattern);
      return;
    }

    try {
      await ref.read(reservationRepositoryProvider).updateTimes(
            r.id,
            startsAt: window.start,
            endsAt: window.end,
          );
    } catch (e, st) {
      debugPrint('reservation edit failed: $e\n$st');
      TraceLogger.instance.error(
          'reservations', 'reservation edit failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      // #574 — the server's own reason (granularity, one-place, quota),
      // not a generic "taken": the edit flow used to swallow it.
      AppSnack.error(
        context,
        bookingErrorText(
          l10n,
          e,
          l10n?.reserveBookingFailed ??
              'Could not reserve — the seat may have just been taken.',
          stepMinutes: granularity.stepMinutes,
        ),
      );
      return;
    }
    invalidateBookingData(ref);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      l10n?.reservationUpdatedSnack ?? 'Reservation updated.',
    );
  }

  /// The next canonical LATER end for a running booking (#574), or null
  /// when nothing later exists: under half-day granularity a morning
  /// grows to the day's end; grids/hours/flexible may pick any later
  /// time; a booking already at its day's end has nowhere to grow.
  DateTime? _laterEndFor(WidgetRef ref, Reservation r) {
    final granularity = ref.read(bookingGranularityProvider).value ??
        BookingGranularity.flexible;
    final day = WorkspaceTime.dateOf(r.startsAt);
    final dayEnd = HalfDayWindows.fullDay(day).end;
    if (granularity == BookingGranularity.halfDay ||
        granularity == BookingGranularity.fullDay) {
      return r.endsAt.isBefore(dayEnd) ? dayEnd : null;
    }
    // Grids, hours, flexible: anything later the same day works — the
    // picker decides; the day's midnight bounds it.
    final next = day.add(const Duration(days: 1));
    final midnight = WorkspaceTime.at(next.year, next.month, next.day, 0, 0);
    return r.endsAt.isBefore(midnight) ? midnight : null;
  }

  /// The canonical EARLIER end a running booking may shrink to (#638),
  /// or null when nothing earlier is reachable. Day-based granularity
  /// has exactly one earlier canonical edge — the half-day boundary —
  /// and it only counts while it still lies ahead of [now] (and after
  /// the immovable start). Grids/hours/flexible let the picker choose:
  /// they qualify as soon as one whole step still fits between now and
  /// the current end.
  DateTime? _earlierEndFor(WidgetRef ref, Reservation r, DateTime now) {
    final granularity = ref.read(bookingGranularityProvider).value ??
        BookingGranularity.flexible;
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
    final minutes =
        granularity.snapMinutesOfDay(picked.hour * 60 + picked.minute);
    return WorkspaceTime.at(day.year, day.month, day.day, 0, 0)
        .add(Duration(minutes: minutes.clamp(0, 24 * 60)));
  }

  /// #574 — extend a RUNNING booking's end within the workspace's
  /// granularity. Day-based: one confirm to the day's end (that IS the
  /// only later canonical edge). Grids/hours: a snapped time picker.
  Future<void> _extendEnd(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final r = reservation;
    final granularity = ref.read(bookingGranularityProvider).value ??
        BookingGranularity.flexible;
    final day = WorkspaceTime.dateOf(r.startsAt);

    DateTime? newEnd;
    if (granularity.isDayBased) {
      newEnd = HalfDayWindows.fullDay(day).end;
    } else {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          WorkspaceTime.display(r.endsAt),
        ),
      );
      if (picked == null || !context.mounted) return;
      newEnd = _snappedOnDay(day, picked, granularity);
    }
    if (!newEnd.isAfter(r.endsAt)) {
      if (!context.mounted) return;
      AppSnack.info(
        context,
        l10n?.reservationExtendLaterOnly ??
            'Pick a time after the current end.',
      );
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
  Future<void> _endEarly(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final r = reservation;
    final granularity = ref.read(bookingGranularityProvider).value ??
        BookingGranularity.flexible;
    final now = ref.read(clockProvider).now();
    final day = WorkspaceTime.dateOf(r.startsAt);

    DateTime newEnd;
    if (granularity.isDayBased) {
      final boundary = _earlierEndFor(ref, r, now);
      if (boundary == null) return; // the button is not offered then
      newEnd = boundary;
    } else {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          WorkspaceTime.display(r.endsAt),
        ),
      );
      if (picked == null || !context.mounted) return;
      newEnd = _snappedOnDay(day, picked, granularity);
    }
    // Ahead of now AND before the current end — the two halves of the
    // server's own rule, refused here with the reason instead of a
    // round-trip that says "invalid".
    if (!newEnd.isBefore(r.endsAt) || !newEnd.isAfter(now)) {
      if (!context.mounted) return;
      AppSnack.info(
        context,
        l10n?.reservationEndEarlyAheadOnly ??
            'Pick a time still ahead of now and before the current end.',
      );
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
    final l10n = AppLocalizations.of(context);
    final r = reservation;
    try {
      await ref.read(reservationRepositoryProvider).updateTimes(
            r.id,
            startsAt: r.startsAt,
            endsAt: newEnd,
          );
    } catch (e, st) {
      TraceLogger.instance.error(
          'reservations', 'reservation end change failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        bookingErrorText(
          l10n,
          e,
          l10n?.reserveBookingFailed ??
              'Could not reserve — the seat may have just been taken.',
          stepMinutes: granularity.stepMinutes,
        ),
      );
      return;
    }
    invalidateBookingData(ref);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      l10n?.reservationUpdatedSnack ?? 'Reservation updated.',
    );
  }

  /// Repeat-modality picker for the edit flow (spec §5.2): the same
  /// choices as the booking sheet's Repeat dropdown, as tappable rows.
  Future<SeriesPattern?> _pickPattern(
    BuildContext context,
    AppLocalizations? l10n,
  ) {
    Widget row(String key, SeriesPattern? p, String label, IconData icon) =>
        ListTile(
          key: ValueKey(key),
          leading: Icon(icon),
          title: Text(label),
          onTap: () => Navigator.of(context).pop(p),
        );
    return showModalBottomSheet<SeriesPattern?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row('edit-repeat-none', null,
                l10n?.repeatNone ?? 'Does not repeat', Icons.event_outlined),
            row('edit-repeat-daily', SeriesPattern.daily,
                l10n?.repeatDaily ?? 'Every day', Icons.repeat),
            row('edit-repeat-weekdays', SeriesPattern.weekdays,
                l10n?.repeatWeekdays ?? 'Every weekday',
                Icons.work_outline),
            row('edit-repeat-weekly', SeriesPattern.weekly,
                l10n?.repeatWeekly ?? 'Weekly', Icons.view_week_outlined),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Turns this single booking into a series from [window]: cancel the
  /// one, then book the recurrence on the same seat (28-day horizon, the
  /// booking-sheet default). Cancel-first so the first instance does not
  /// collide with the reservation being replaced.
  Future<void> _convertToSeries(
    BuildContext context,
    WidgetRef ref,
    HalfDayWindow window,
    SeriesPattern pattern,
  ) async {
    final l10n = AppLocalizations.of(context);
    final r = reservation;
    final repo = ref.read(reservationRepositoryProvider);
    final seatId = r.seatId;
    if (seatId == null) return; // whole-office series unsupported (spec)
    try {
      await repo.cancel(r.id);
      final result = await repo.createSeries(
        workspaceId: r.workspaceId,
        seatId: seatId,
        firstStart: window.start,
        firstEnd: window.end,
        pattern: pattern,
        until: window.start.add(const Duration(days: 28)),
      );
      invalidateBookingData(ref);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await showSeriesResultDialog(context, result);
    } catch (e, st) {
      debugPrint('convert to series failed: $e\n$st');
      TraceLogger.instance.error(
          'reservations', 'convert to series failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.reserveBookingFailed ??
            'Could not reserve — the seat may have just been taken.',
      );
    }
  }

  Future<HalfDayWindow?> _pickHalfDayWindow(
    BuildContext context,
    AppLocalizations? l10n,
    DateTime day,
  ) {
    return showModalBottomSheet<HalfDayWindow>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('edit-window-am'),
              leading: const Icon(Icons.wb_twilight_outlined),
              title: Text(l10n?.planMorningChip ?? 'Morning'),
              onTap: () => Navigator.of(sheetContext)
                  .pop(HalfDayWindows.morning(day)),
            ),
            ListTile(
              key: const ValueKey('edit-window-pm'),
              leading: const Icon(Icons.wb_sunny_outlined),
              title: Text(l10n?.planAfternoonChip ?? 'Afternoon'),
              onTap: () => Navigator.of(sheetContext)
                  .pop(HalfDayWindows.afternoon(day)),
            ),
            ListTile(
              key: const ValueKey('edit-window-day'),
              leading: const Icon(Icons.today_outlined),
              title: Text(l10n?.reserveFullDayChip ?? 'Full day'),
              onTap: () => Navigator.of(sheetContext)
                  .pop(HalfDayWindows.fullDay(day)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// From/to clock pickers on the booking's device-local day, snapped to
  /// the granularity's step — the same slot language as the hub's chips.
  Future<HalfDayWindow?> _pickTimes(
    BuildContext context,
    AppLocalizations? l10n,
    BookingGranularity granularity,
  ) async {
    final r = reservation;
    final snap = granularity.stepMinutes ?? 15;
    final local = WorkspaceTime.wall(r.startsAt);
    final endLocal = WorkspaceTime.wall(r.endsAt);
    final from = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
      helpText: l10n?.planFromLabel ?? 'From',
    );
    if (from == null || !context.mounted) return null;
    final to = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(endLocal),
      helpText: l10n?.planToLabel ?? 'To',
    );
    if (to == null) return null;
    DateTime snapDown(int hour, int minute) {
      // #638 — the shared grid rule, not a private copy of it.
      final m = granularity.snapMinutesOfDay(hour * 60 + minute);
      return DateTime(local.year, local.month, local.day, m ~/ 60, m % 60);
    }

    final start = snapDown(from.hour, from.minute);
    var end = snapDown(to.hour, to.minute);
    if (!end.isAfter(start)) end = start.add(Duration(minutes: snap));
    return (start: start, end: end);
  }
}

/// Opens the detail sheet AND owns the "Show on plan" jump (#182): the
/// button pops with the seat's [SeatContext]; this helper then sets the
/// plan focus and leaves for the Plan tab. Every surface must open the
/// sheet through here — a caller that discards the result silently
/// breaks the button, which is exactly how the directory shipped it
/// (field bug #422, pasted-consumer drift across calendar and hub).
Future<void> showReservationDetail(
  BuildContext context,
  WidgetRef ref,
  Reservation reservation,
) async {
  final target = await showModalBottomSheet<SeatContext>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ReservationDetailSheet(reservation: reservation),
  );
  if (target == null || !context.mounted) return;
  ref.read(planFocusControllerProvider.notifier).setFocus(
        PlanFocus(
          levelId: target.levelId,
          seatId: reservation.seatId,
          // #576 — a whole-desk/office/level booking highlights the
          // SPACE it covers, not nothing.
          deskId: reservation.deskId,
          officeId: reservation.officeId,
          wholeLevel: reservation.levelId != null,
          at: reservation.startsAt,
        ),
      );
  // The jump must land on a VISIBLE plan: when the detail sheet was
  // stacked over other sheets (a conversation's message link, the
  // booking sheet), those would keep covering the plan tab — close
  // every remaining sheet/dialog first (field report).
  Navigator.of(context).popUntil((route) =>
      route is! ModalBottomSheetRoute && route is! RawDialogRoute);
  context.go('/plan');
}
