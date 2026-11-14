// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — a booking opened beside the grid (K2): who, where, when and
// in what state, and the one door to everything that can be done with it (the
// booking's own sheet: edit the window, stay longer, cancel, show on the plan).
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
import '../../core/ui/empty_state.dart';
import '../../core/ui/inline_banner.dart';
import '../../core/ui/loading_view.dart';
import '../../features/events/providers/event_providers.dart' show invalidateBookingData;
import '../../features/reservations/domain/reservation.dart';
import '../../features/reservations/domain/reservation_repository.dart' show ReservationUnreadable;
import '../../features/reservations/presentation/widgets/booking_range_text.dart';
import '../../features/reservations/presentation/widgets/my_reservations_layout.dart' show myReservationStatusWords;
import '../../features/reservations/presentation/widgets/reservation_detail_sheet.dart'
    show ownBookingOffers, reservationActionsOf, showReservationDetail;
import '../../features/reservations/presentation/widgets/reservation_status_note.dart';
import '../../features/workspace/providers/workspace_providers.dart' show myMemberProvider;

import 'desk_calendar.dart';
import 'desk_calendar_providers.dart';

/// The key of the pane's close button.
const Key _deskPaneCloseKey = ValueKey('desk-booking-pane-close');

/// The key of the pane's button to the booking's own sheet.
const Key _deskPaneActionsKey = ValueKey('desk-booking-pane-actions');

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

  @override
  void didUpdateWidget(DeskBookingPane old) {
    super.didUpdateWidget(old);
    if (old.bookingId != widget.bookingId) _refusal = null;
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
        AsyncError(:final error) when error is ReservationUnreadable =>
          EmptyState(
            icon: Icons.visibility_off_outlined,
            title: l10n.reservationUnreadable,
          ),
        AsyncError() => EmptyState(
          icon: Icons.error_outline,
          title: l10n.periodReservationsFailed,
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
        FilledButton.icon(
          key: _deskPaneActionsKey,
          icon: const Icon(Icons.tune),
          label: Text(l10n.calendarDeskBookingActions),
          onPressed: () => showReservationDetail(context, ref, r),
        ),
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
