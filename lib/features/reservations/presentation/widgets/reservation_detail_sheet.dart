// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/seat_context.dart';
import '../../../plan/presentation/widgets/seat_accessory_row.dart';
import '../../../plan/providers/seat_context_providers.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_repository.dart';
import 'booking_range_text.dart';
import 'series_result_dialog.dart';
import '../../providers/reservation_providers.dart';

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
    // The actions belong to the owner of a still-upcoming booking; past,
    // running or foreign ones stay read-only here (check-out and admin
    // flows live elsewhere).
    final editable = r.memberId == myMemberId &&
        r.status == ReservationStatus.reserved;

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
              subtitle:
                  target == null && r.seriesId == null && r.levelId == null
                      ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (target != null) Text(target.locationLine),
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
          ],
        ),
      ),
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
      AppSnack.error(
        context,
        l10n?.reserveBookingFailed ??
            'Could not reserve — the seat may have just been taken.',
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
    final local = r.startsAt.toLocal();
    final endLocal = r.endsAt.toLocal();
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
      final m = (hour * 60 + minute) ~/ snap * snap;
      return DateTime(local.year, local.month, local.day, m ~/ 60, m % 60);
    }

    final start = snapDown(from.hour, from.minute);
    var end = snapDown(to.hour, to.minute);
    if (!end.isAfter(start)) end = start.add(Duration(minutes: snap));
    return (start: start, end: end);
  }
}
