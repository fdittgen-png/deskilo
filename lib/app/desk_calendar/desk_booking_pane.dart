// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — a booking opened beside the grid (K2): who, where, when and
// in what state. #4054 — and what this reader can do with it, each as its own
// button: no door to a sheet that only lists them, none that promises an
// action the reader does not have.
// #3843 — edit, cancel and stay longer stand in the pane's own row, offered
// where the sheet offers them (the booking's own member), through the same
// actions: nothing closes, cancel asks as a short task, a refusal is said in
// the pane, and the grid, the table and the pane read again.
// The booking's address (`/calendar?res=<id>`) names it, so a reload or a link
// opens the same pane.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/time/clock.dart';
import '../../core/ui/async_read_body.dart';
import '../../core/ui/empty_state.dart';
import '../../core/ui/inline_banner.dart';
import '../../core/ui/loading_view.dart';
import '../../features/events/providers/event_providers.dart' show invalidateBookingData;
import '../../features/reservations/domain/reservation.dart';
import '../../features/reservations/domain/reservation_repository.dart' show ReservationUnreadable;
import '../../features/reservations/presentation/widgets/booking_range_text.dart';
import '../../features/reservations/presentation/widgets/calendar_file_button.dart';
import '../../features/reservations/presentation/widgets/my_reservations_layout.dart' show myReservationStatusWords;
import '../../features/reservations/presentation/widgets/reservation_detail_sheet.dart'
    show
        BoundReservation,
        captureBoundReservation,
        ownBookingOffers,
        reservationActionsOf,
        watchReservationPlace;
import '../../features/reservations/presentation/widgets/reservation_status_note.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart'
    show enabledFeaturesSyncProvider, myMemberProvider;

import 'desk_calendar.dart';
import 'desk_calendar_providers.dart';

/// The key of the pane's close button.
const Key _deskPaneCloseKey = ValueKey('desk-booking-pane-close');

/// The key of the pane's button that shows the booking on the plan.
const Key _deskPaneOnPlanKey = ValueKey('desk-pane-show-on-plan');

class DeskBookingPane extends ConsumerStatefulWidget {
  const DeskBookingPane({
    required this.bookingId,
    required this.known,
    required this.names,
    required this.placeNames,
    required this.onClose,
    super.key,
  });

  final String bookingId;

  /// The booking as the grid's own read has it, when it has it: it follows
  /// every change the grid does. Otherwise it is read by id.
  final Reservation? known;
  final Map<String, String> names;
  final Map<String, String> placeNames;
  final VoidCallback onClose;

  @override
  ConsumerState<DeskBookingPane> createState() => _DeskBookingPaneState();
}

class _DeskBookingPaneState extends ConsumerState<DeskBookingPane> {
  /// What the server refused last, said in the pane until the next action.
  String? _refusal;

  /// #4157 — the commands of the context this booking was shown in, taken when
  /// the pane opens on it (and again when it opens on another booking), never
  /// with a rebuild: a switch of installation, workspace or account while the
  /// pane is open leaves them on the context the booking was read under, and
  /// every action re-reads the context before it sends.
  BoundReservation? _bound;

  @override
  void initState() {
    super.initState();
    _bound = captureBoundReservation(ref);
  }

  @override
  void didUpdateWidget(DeskBookingPane old) {
    super.didUpdateWidget(old);
    if (old.bookingId != widget.bookingId) {
      _refusal = null;
      _bound = captureBoundReservation(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final known = widget.known;
    final booking = known != null
        ? AsyncData<Reservation?>(known)
        : ref.watch(deskBookingByIdProvider(widget.bookingId));
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.calendarDeskBooking),
        actions: [
          IconButton(
            key: _deskPaneCloseKey,
            tooltip: MaterialLocalizations.of(context).closeButtonLabel,
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
        ],
      ),
      body: switch (booking) {
        AsyncData(value: final r?) => _body(context, r),
        AsyncData() => EmptyState(
          icon: Icons.event_busy_outlined,
          title: l10n.noteRefGone,
        ),
        // #3884 — it exists, but this version cannot show it: not "failed".
        // #4414 kept: a typed answer worded as itself, not a failed read
        AsyncError(:final error) when error is ReservationUnreadable =>
          EmptyState(
            icon: Icons.visibility_off_outlined,
            title: l10n.reservationUnreadable,
          ),
        AsyncError(:final error) => ListView(
          padding: AppSpacing.mdAll,
          children: [
            ReadFailureBanner(
              error: error,
              onRetry: () =>
                  ref.invalidate(deskBookingByIdProvider(widget.bookingId)),
            ),
          ],
        ),
        _ => const LoadingView(),
      },
    );
  }

  Widget _body(BuildContext context, Reservation r) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final place = widget.placeNames[bookingTargetId(r)] ?? r.spaceLabel ?? '';
    final date = format
        .dates(DateShape.weekdayMonthDay)
        .format(format.wall(r.startsAt));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(widget.names[r.memberId] ?? ''),
          subtitle: Text(l10n.calendarDeskColumnMember),
        ),
        ListTile(
          leading: const Icon(Icons.event_seat_outlined),
          title: Text(place),
          subtitle: Text(l10n.calendarDeskColumnPlace),
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: Text(
            '$date · ${bookingRangeText(context, format, l10n, r.startsAt, r.endsAt)}',
          ),
          subtitle: Text(
            r.seriesId == null
                ? myReservationStatusWords(l10n, r.status)
                : '${myReservationStatusWords(l10n, r.status)} · '
                      '${repeatLabelText(l10n, r.seriesPattern)}',
          ),
        ),
        ReservationStatusNote(
          reservation: r,
          now: ref.read(clockProvider).now(),
        ),
        const SizedBox(height: AppSpacing.lg),
        ..._ownActions(context, r),
        if (watchReservationPlace(ref, r).value case final target?)
          OutlinedButton.icon(
            key: _deskPaneOnPlanKey,
            icon: const Icon(Icons.map_outlined),
            label: Text(l10n.calendarShowOnPlan),
            onPressed: () => reservationActionsOf(
              ref,
              r,
              bound: _bound,
            ).showOnPlan(context, ref, target.levelId),
          ),
        if (r.memberId == ref.watch(myMemberProvider).value?.id &&
            ref
                .watch(enabledFeaturesSyncProvider)
                .contains(WorkspaceFeature.calendarFileExport)) ...[
          const SizedBox(height: AppSpacing.sm),
          CalendarFileButton(reservation: r),
        ],
      ],
    );
  }

  /// #3843 — edit, cancel and stay longer, where the sheet offers them; a
  /// refusal above them.
  List<Widget> _ownActions(BuildContext context, Reservation r) {
    final l10n = context.l10n;
    final actions = reservationActionsOf(
      ref,
      r,
      bound: _bound,
      inPane: true,
      onRefused: (refusal) {
        if (mounted) setState(() => _refusal = refusal);
      },
      refresh: () {
        invalidateBookingData(ref);
        ref.invalidate(deskBookingByIdProvider);
      },
    );
    final mine = r.memberId == ref.watch(myMemberProvider).value?.id;
    final offered = ownBookingOffers(ref, r, actions, mine: mine);
    Widget button(
      String key,
      IconData icon,
      String label,
      Future<void> Function(BuildContext context, WidgetRef ref) run,
    ) =>
        OutlinedButton.icon(
          key: ValueKey(key),
          icon: Icon(icon),
          label: Text(label),
          onPressed: () {
            setState(() => _refusal = null);
            unawaited(run(context, ref));
          },
        );
    final row = [
      if (offered.editable) ...[
        button(
          'desk-pane-edit',
          Icons.edit_calendar_outlined,
          l10n.reservationEditTimes,
          actions.editTimes,
        ),
        button(
          'desk-pane-cancel',
          Icons.event_busy_outlined,
          l10n.planCancelReservationButton,
          actions.cancel,
        ),
      ],
      if (offered.extendable)
        button(
          'desk-pane-extend',
          Icons.more_time_outlined,
          l10n.reservationExtendButton,
          actions.extendEnd,
        ),
      if (offered.endEarlyable)
        button(
          'desk-pane-end-early',
          Icons.timer_off_outlined,
          l10n.reservationEndEarlyButton,
          actions.endEarly,
        ),
      if (offered.deletionRequestable)
        button(
          'desk-pane-delete-request',
          Icons.delete_outline,
          l10n.reservationDeleteRequestButton,
          actions.requestDeletion,
        ),
    ];
    return [
      if (_refusal case final refusal?)
        InlineBanner(
          key: const ValueKey('desk-pane-refusal'),
          icon: Icons.error_outline,
          text: refusal,
        ),
      if (row.isNotEmpty) ...[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: row,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ];
  }
}
