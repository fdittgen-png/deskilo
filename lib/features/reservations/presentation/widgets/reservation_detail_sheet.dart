// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/l10n/lexicon.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/trace/act_trace.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/presentation/widgets/event_validation_trail.dart';
import '../../../events/providers/event_providers.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/seat_context.dart';
import '../../../plan/presentation/widgets/seat_accessory_row.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../plan/providers/plan_focus_controller.dart';
import '../../../plan/providers/seat_context_providers.dart';
import '../../../task_recorder/domain/action_registry.dart'
    show RecorderActions;
import '../../../task_recorder/presentation/recorder_seam.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/change_reservation.dart';
import '../../domain/booking_error_text.dart';
import '../../domain/own_booking_removal.dart';
import '../../domain/picked_time.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_repository.dart';
import '../../providers/reservation_providers.dart';
import 'booking_range_text.dart';
import 'calendar_file_button.dart';
import 'reservation_status_note.dart';
import 'series_result_dialog.dart';

part 'reservation_detail_sheet_part1.dart';
part 'reservation_detail_sheet_part2.dart';

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
@visibleForTesting
class ReservationDetailSheet extends ConsumerWidget {
  const ReservationDetailSheet({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
    // #2328 — the same rule the plan's "your seat" sheet reads.
    final removal = ownBookingRemovalOf(ref, r);
    final editable = mine && removal == OwnBookingRemoval.cancel;
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
    final deletionRequestable =
        mine && removal == OwnBookingRemoval.requestDeletion;
    // #1643 — MY booking, in my own calendar: any state, since a
    // cancelled one exports as cancelled rather than being hidden.
    final calendarFile = mine &&
        ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.calendarFileExport);

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
                ' · ${bookingRangeText(context, appFormatOf(context), l10n, r.startsAt, r.endsAt)}',
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
                                '${lexiconText(context, key: 'deskDetail', fallback: l10n.deskDetail)}'
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
                                '${lexiconText(context, key: 'levelDetail', fallback: l10n.levelDetail)}'
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
            ReservationStatusNote(reservation: r, now: now),
            if (seatId != null) SeatAccessoryRow(seatId: seatId),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('reservation-detail-sheet-calendar-show-on-plan'),
              icon: const Icon(Icons.map_outlined),
              onPressed: target == null
                  ? null
                  : () => Navigator.of(context).pop(target),
              label: Text(l10n.calendarShowOnPlan),
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
                        l10n.reservationEditTimes,
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
                        l10n.planCancelReservationButton,
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
                  l10n.reservationExtendButton,
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
                  l10n.reservationEndEarlyButton,
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
                label: Text(l10n.reservationDeleteRequestButton),
              ),
            ],
            if (calendarFile) ...[
              const SizedBox(height: 8),
              CalendarFileButton(reservation: r),
            ],
            // #841 — the booking says who decided about it. A deletion
            // request travels in the payload, not on events.reservation_id
            // (0097 keeps that column free so a reject does not cancel
            // the booking), so both links are followed.
            if (reservationEventId(ref, reservation.id) case final eventId?)
              EventValidationTrail(eventId: eventId),
          ],
        ),
      ),
    );
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
  recordTaskStep(ref, RecorderActions.viewDetails); // #1865
  final target = await showAppSheet<SeatContext>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ReservationDetailSheet(reservation: reservation),
  );
  if (target == null && context.mounted) {
    recordTaskStep(ref, RecorderActions.back); // #1865
  }
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

// #2328 — removing MY booking, shared with the plan's "your seat" sheet
// so both offer the same action for the same state and file the same
// request.

/// [ownBookingRemoval] on the real clock and this space's features.
OwnBookingRemoval ownBookingRemovalOf(WidgetRef ref, Reservation r) =>
    ownBookingRemoval(
      r,
      now: ref.read(clockProvider).now(),
      deletionRequests: ref
          .read(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.deletionRequests),
    );

/// #492 — the request dialog: explains that an owner/admin validates
/// (forgotten check-in vs unused booking), takes an optional reason,
/// and files the pending event. True once the request is filed.
Future<bool> requestBookingDeletion(
  BuildContext context,
  WidgetRef ref,
  Reservation reservation,
) async {
  // English only where no localization is installed (a bare test app).
  final l10n =
      context.l10n;
  final reasonController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(scrollable: true,
      title: Text(l10n.reservationDeleteRequestButton),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.reservationDeleteRequestExplain),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('reservation-delete-reason'),
            controller: reasonController,
            maxLength: 300,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.reservationDeleteReasonLabel,
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('reservation-detail-sheet-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('reservation-delete-submit'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.reservationDeleteSubmit),
        ),
      ],
    ),
  );
  final reason = reasonController.text;
  if (confirmed != true || !context.mounted) return false;
  if (!await runGuarded(
    context,
    domain: 'reservations',
    message: 'reservation deletion request failed',
    action: () => ref
        .read(eventRepositoryProvider)
        .requestReservationDeletion(reservation.id, reason: reason),
  )) {
    return false;
  }
  invalidateBookingData(ref);
  if (!context.mounted) return true;
  AppSnack.success(context, l10n.reservationDeleteSubmitted);
  return true;
}
