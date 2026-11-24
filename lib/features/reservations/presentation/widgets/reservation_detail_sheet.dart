// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/l10n/lexicon.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../events/presentation/widgets/event_validation_trail.dart';
import '../../../events/providers/event_providers.dart';
import '../../../plan/domain/seat_context.dart';
import '../../../plan/presentation/widgets/seat_accessory_row.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../plan/providers/seat_context_providers.dart';
import '../../../task_recorder/domain/action_registry.dart'
    show RecorderActions;
import '../../../task_recorder/presentation/recorder_seam.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/bound_reservation.dart';
import '../../domain/own_booking_removal.dart';
import '../../domain/reservation.dart';
import '../../providers/reservation_providers.dart';
import 'booking_range_text.dart';
import 'calendar_file_button.dart';
import 'reservation_deletion_dialog.dart';
import 'reservation_detail_actions.dart';
import 'reservation_status_note.dart';

export '../../application/bound_reservation.dart'
    show BoundReservation, StaleReservationContext;

/// #4157 — the reservation commands of the workspace context on screen now,
/// taken when a confirmation OPENS (before its first await), never when its
/// last button is tapped: the context the displayed data was read under is the
/// one the command runs on, or it does not run. Null when there is none ready
/// (signed out, no workspace, still resolving): the confirmation then opens
/// nothing that could write.
BoundReservation? captureBoundReservation(WidgetRef ref) {
  final origin = ref.read(readyWorkspaceContextProvider);
  if (origin == null) return null;
  return BoundReservation(
    origin: origin,
    reservations: ref.read(reservationRepositoryProvider),
    recovery: ref.read(bookingRecoveryProvider),
    // Read NOW, each time: a disposed screen's ref throws, and a context that
    // cannot be read is not the origin.
    readContext: () async => ref.read(readyWorkspaceContextProvider),
  );
}

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
class ReservationDetailSheet extends ConsumerStatefulWidget {
  const ReservationDetailSheet({super.key, required this.reservation});

  final Reservation reservation;

  @override
  ConsumerState<ReservationDetailSheet> createState() =>
      _ReservationDetailSheetState();
}

class _ReservationDetailSheetState
    extends ConsumerState<ReservationDetailSheet> {
  /// #4157 — the commands of the context this sheet OPENED in: taken once,
  /// here, never with a rebuild. A switch of installation, workspace or
  /// account while it is open leaves them on the context its data was read
  /// under, and every action re-reads the context before it sends.
  late final BoundReservation? _bound = captureBoundReservation(ref);

  @override
  Widget build(BuildContext context) {
    final reservation = widget.reservation;
    final l10n = context.l10n;
    final r = reservation;
    final seatId = r.seatId;
    // Self-loading like SeatAccessoryRow: while resolving (or when the
    // target vanished) the location line is simply absent and the jump
    // button disabled — the sheet itself never blocks.
    final target = watchReservationPlace(ref, r).value;

    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final actions = reservationActionsOf(ref, r, bound: _bound);
    // The actions belong to the owner of a still-upcoming booking; a
    // PAST or already CHECKED-IN one is never deleted directly (#492) —
    // deleting it becomes a REQUEST an owner/admin validates (was the
    // check-in forgotten, or was the booking unused?).
    final now = ref.read(clockProvider).now();
    final mine = r.memberId == myMemberId;
    final offered = ownBookingOffers(ref, r, actions, mine: mine);
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
                '${appFormatOf(context).dates(DateShape.weekdayMonthDay).format(appFormatOf(context).wall(r.startsAt))}'
                ' · ${bookingRangeText(context, appFormatOf(context), l10n, r.startsAt, r.endsAt)}',
              ),
              subtitle: _subtitle(context, r, target),
            ),
            ReservationStatusNote(reservation: r, now: now),
            if (seatId != null) SeatAccessoryRow(seatId: seatId),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey('reservation-detail-sheet-calendar-show-on-plan'),
              icon: const Icon(Icons.map_outlined),
              onPressed: target == null
                  ? null
                  : () => Navigator.of(context).pop(target),
              label: Text(l10n.calendarShowOnPlan),
            ),
            ..._ownActions(context, ref, actions, offered),
            if (calendarFile) ...[
              const SizedBox(height: AppSpacing.sm),
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

  /// Where the booking is: the seat's location, the substitution text of a
  /// deleted target, the whole desk or level, and the repetition.
  Widget? _subtitle(BuildContext context, Reservation r, SeatContext? target) {
    final l10n = context.l10n;
    return target == null &&
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
                                name == null
                                    ? lexiconText(context, key: 'deskDetail', fallback: l10n.deskDetail)
                                    : l10n.titleDashDetail(
                                        lexiconText(context, key: 'deskDetail', fallback: l10n.deskDetail),
                                        name,
                                      ),
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
                                name == null
                                    ? lexiconText(context, key: 'levelDetail', fallback: l10n.levelDetail)
                                    : l10n.titleDashDetail(
                                        lexiconText(context, key: 'levelDetail', fallback: l10n.levelDetail),
                                        name,
                                      ),
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
                    );
  }

  /// What I may still do with my own booking (the sheet's build decides).
  List<Widget> _ownActions(
    BuildContext context,
    WidgetRef ref,
    ReservationDetailActions actions,
    OwnBookingOffers offered,
  ) {
    final l10n = context.l10n;
    return [
            if (offered.editable) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('reservation-edit'),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      onPressed: () => actions.editTimes(context, ref),
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
                      onPressed: () => actions.cancel(context, ref),
                      label: Text(
                        l10n.planCancelReservationButton,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (offered.extendable) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey('reservation-extend'),
                icon: const Icon(Icons.more_time_outlined),
                onPressed: () => actions.extendEnd(context, ref),
                label: Text(
                  l10n.reservationExtendButton,
                ),
              ),
            ],
            if (offered.endEarlyable) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey('reservation-end-early'),
                icon: const Icon(Icons.timelapse_outlined),
                onPressed: () => actions.endEarly(context, ref),
                label: Text(
                  l10n.reservationEndEarlyButton,
                ),
              ),
            ],
            if (offered.deletionRequestable) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey('reservation-delete-request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => actions.requestDeletion(context, ref),
                // The label says REQUEST — nothing is deleted here.
                label: Text(l10n.reservationDeleteRequestButton),
              ),
            ],
    ];
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
  reservationActionsOf(
    ref,
    reservation,
    bound: null,
  ).showOnPlan(context, ref, target.levelId);
}

/// #4054 — where [r] stands on the plan (its seat's or its office's level
/// and names), as it is read; none for a booking of a whole level or desk.
AsyncValue<SeatContext?> watchReservationPlace(WidgetRef ref, Reservation r) {
  final seatId = r.seatId;
  final officeId = r.officeId;
  return seatId != null
      ? ref.watch(seatContextProvider(seatId))
      : officeId != null
      ? ref.watch(officeContextProvider(officeId))
      : const AsyncData<SeatContext?>(null);
}


/// The actions on [r] as this space reads them. #3843 — the desk calendar's
/// pane passes [inPane], where a refusal goes ([onRefused]) and what to read
/// again after a change ([refresh]; by default every booking read).
ReservationDetailActions reservationActionsOf(
  WidgetRef ref,
  Reservation r, {
  required BoundReservation? bound,
  bool inPane = false,
  void Function(String refusal)? onRefused,
  void Function()? refresh,
}) => ReservationDetailActions(
  r,
  readGranularity: () => ref.read(bookingGranularityProvider).value,
  seriesAllowed: () => ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.seriesBooking),
  refresh: refresh ?? () => invalidateBookingData(ref),
  bound: bound,
  inPane: inPane,
  onRefused: onRefused,
);

/// What a booking's own member may do with it now.
typedef OwnBookingOffers = ({
  bool editable,
  bool extendable,
  bool endEarlyable,
  bool deletionRequestable,
});

/// #3843 — the one rule for what [r]'s own member ([mine]) may do with it,
/// read by the booking's sheet and by the desk calendar's pane. The actions
/// belong to the owner of a still-upcoming booking; a PAST or already
/// CHECKED-IN one is never deleted directly (#492) — deleting it becomes a
/// REQUEST an owner/admin validates. #574 — a RUNNING booking may still grow
/// to a later canonical edge; #638 — and may SHRINK to an earlier one ahead
/// of now.
OwnBookingOffers ownBookingOffers(
  WidgetRef ref,
  Reservation r,
  ReservationDetailActions actions, {
  required bool mine,
}) {
  final now = ref.read(clockProvider).now();
  // #2328 — the same rule the plan's "your seat" sheet reads.
  final removal = ownBookingRemovalOf(ref, r);
  final running =
      mine &&
      r.status == ReservationStatus.checkedIn &&
      r.endsAt.isAfter(now);
  return (
    editable: mine && removal == OwnBookingRemoval.cancel,
    extendable: running && actions.laterEndFor(r) != null,
    endEarlyable: running && actions.earlierEndFor(r, now) != null,
    deletionRequestable: mine && removal == OwnBookingRemoval.requestDeletion,
  );
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
  Reservation reservation, {
  required BoundReservation bound,
}) async {
  // #4157 — the events of the context the dialog OPENS in, read before its
  // await and used only while the context is still the one the booking was
  // shown in.
  if (!await bound.isCurrent()) {
    if (context.mounted) {
      AppSnack.info(context, context.l10n.reservationContextChanged, replace: true);
    }
    return false;
  }
  if (!context.mounted) return false;
  final events = ref.read(eventRepositoryProvider);
  final l10n = context.l10n;
  final reason = await askDeletionReason(context);
  if (reason == null || !context.mounted) return false;
  // #4157 — the dialog was an await: the request is filed on the context the
  // booking was shown in, or not at all.
  if (!await bound.isCurrent()) {
    if (context.mounted) {
      AppSnack.info(context, l10n.reservationContextChanged, replace: true);
    }
    return false;
  }
  if (!context.mounted) return false;
  if (!await runGuarded(
    context,
    domain: 'reservations',
    message: 'reservation deletion request failed',
    action: () =>
        events.requestReservationDeletion(reservation.id, reason: reason),
  )) {
    return false;
  }
  // It was filed on its own context; a later one is not told so, nor refreshed.
  if (!await bound.isCurrent()) return true;
  invalidateBookingData(ref);
  if (!context.mounted) return true;
  AppSnack.success(context, l10n.reservationDeleteSubmitted);
  return true;
}
