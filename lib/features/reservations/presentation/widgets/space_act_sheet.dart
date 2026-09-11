// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/presentation/seat_occupancy.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/booking_error_text.dart';
import '../../domain/booking_gate.dart';
import '../../domain/reservation.dart';
import '../booking_gate_scope.dart';
import '../../providers/reservation_providers.dart';
import 'message_reserver.dart';
import 'space_act_form.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/trace/act_trace.dart';

/// #622 — the authenticated act sheet: scanning a seat's QR card (or
/// tapping its chair's NFC tag, or picking it in a desk/office space
/// sheet) opens the SAME action + derived-period flow as the kiosk
/// one-sheet ([SpaceActForm]) — no badge step, the signed-in member
/// confirms and the normal repository calls act:
///
/// - own reservation the check-in rules accept → check THAT in;
/// - free → the walk-up `create(checkIn: true)` books implicitly;
/// - held by another member → the blocking booking is named and, with
///   messaging on, "Message …" opens the conversation seeded with the
///   reservation reference.
Future<void> showSpaceActSheet(
  BuildContext context, {
  required Seat seat,
  FloorPlan? plan,
  required String title,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SpaceActSheet(seat: seat, plan: plan, title: title),
);

class SpaceActSheet extends ConsumerStatefulWidget {
  const SpaceActSheet({
    super.key,
    required this.seat,
    this.plan,
    required this.title,
  });

  final Seat seat;

  /// The seat's floor plan when the opener has it — lets the blocking
  /// resolution see whole-desk/office/level bookings covering the seat.
  final FloorPlan? plan;
  final String title;

  @override
  ConsumerState<SpaceActSheet> createState() => _SpaceActSheetState();
}

class _SpaceActSheetState extends ConsumerState<SpaceActSheet> {
  bool _busy = false;

  BookingGranularity get _granularity =>
      ref.watch(bookingGranularityProvider).value ??
      BookingGranularity.flexible;

  /// Today's reservations — client-side outcome resolution (#622): my
  /// own booking to check in, or the blocking one to message about.
  List<Reservation> _dayReservations(DateTime now) =>
      ref.watch(reservationsForDayProvider(dayKeyOf(now))).value ?? const [];

  /// MY reservation of this seat the check-in rules accept (same-day
  /// rule, `checkInWindowOpen` with granularity — #600).
  Reservation? _myCheckInTarget(
    List<Reservation> reservations,
    DateTime now,
    String? myMemberId,
  ) => reservations
      .where(
        (r) =>
            r.memberId == myMemberId &&
            r.seatId == widget.seat.id &&
            r.checkInWindowOpen(now, granularity: _granularity),
      )
      .firstOrNull;

  /// #1135 — MY live check-in on this seat, whatever the window rule
  /// says about it.
  ///
  /// [_myCheckInTarget] cannot answer this: it gates on
  /// `checkInWindowOpen`, whose FIRST clause is
  /// `status != ReservationStatus.reserved → false`. A reservation the
  /// member is already checked into is therefore invisible to it, it
  /// returns null, and `_confirm` reads that null as "nothing of mine
  /// here — walk up and create one". The server then refuses, correctly,
  /// with "you already have a reservation in that period", and the
  /// member is told nothing they can act on.
  ///
  /// That is the whole of the 11:37 sequence in the field trace: five
  /// identical creates in two and a half seconds, every one of them
  /// impossible, on a seat the member was already sitting at.
  Reservation? _myLiveCheckInHere(
    List<Reservation> reservations,
    DateTime now,
    String? myMemberId,
  ) => _myActiveCheckIn(reservations, now, myMemberId);

  /// MY live check-in ON THIS SEAT (#1083). The seat predicate is the
  /// whole point: with `simultaneous_reservations > 1` a member can hold
  /// two seats at once, and scanning one of them must release THAT one.
  /// Without it the branch took `firstOrNull` of an unordered list and
  /// checked the member out of whichever seat came first.
  ///
  /// Ordered by check-in time so that even a seat holding two live rows
  /// — which the server should never allow — resolves the same way twice
  /// rather than by list order.
  Reservation? _myActiveCheckIn(
    List<Reservation> reservations,
    DateTime now,
    String? myMemberId,
  ) {
    final mine = reservations
        .where(
          (r) =>
              r.memberId == myMemberId &&
              r.seatId == widget.seat.id &&
              r.status == ReservationStatus.checkedIn &&
              r.endsAt.isAfter(now),
        )
        .toList()
      ..sort((a, b) => (a.checkedInAt ?? a.startsAt)
          .compareTo(b.checkedInAt ?? b.startsAt));
    return mine.isEmpty ? null : mine.last;
  }

  /// ANOTHER member's reservation holding this seat over the chosen
  /// window — the seat's own booking or a whole desk/office/level one
  /// covering it (space overlays' semantics via [occupantOnSeat]).
  Reservation? _blocking(
    List<Reservation> reservations,
    SpaceActChoice choice,
    String? myMemberId,
  ) {
    if (choice.action == SpaceAction.checkOut) return null;
    final plan = widget.plan;
    final covering = plan == null
        ? reservations
              .where(
                (r) =>
                    r.seatId == widget.seat.id &&
                    r.coversRange(choice.start, choice.end),
              )
              .firstOrNull
        : occupantOnSeat(
            plan: plan,
            seat: widget.seat,
            reservations: reservations,
            from: choice.start,
            to: choice.end,
          );
    if (covering == null || covering.memberId == myMemberId) return null;
    return covering;
  }

  Future<void> _confirm(SpaceActChoice choice) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final me = ref.read(myMemberProvider).value;
    if (workspace == null || _busy) return;
    final now = ref.read(clockProvider).now();
    final reservations = _dayReservations(now);
    setState(() => _busy = true);
    try {
      switch (choice.action) {
        case SpaceAction.checkIn:
          // Own reservation the rules accept → continue into THAT
          // (check_in_reservation); free → the walk-up create books
          // implicitly (#573 snap + walk-up-today rule server-side).
          final mine = _myCheckInTarget(reservations, now, me?.id);
          // #791 — the scan path resolves its target on the DEVICE too,
          // from the same day slice and the same window rule as the map.
          // Recording which branch it took is what makes "the QR worked
          // and the map did not" a comparison instead of a mystery.
          ActTrace.booking.step('scan-check-in', {
            'seat': widget.seat.id,
            'target': mine?.id,
            'route': mine != null ? 'existing-reservation' : 'walk-up',
            'member': me?.id,
            'dayReservations': reservations.length,
            'granularity': _granularity.name,
          });
          if (mine != null) {
            await ref.read(reservationRepositoryProvider).checkIn(mine.id);
          } else if (_myLiveCheckInHere(reservations, now, me?.id)
                  ?.coversRange(choice.start, choice.end) ??
              false) {
            // #1135 — the member is already checked in on this seat, so
            // `_myCheckInTarget` found nothing (it only sees `reserved`).
            // Falling through to the walk-up create here is what produced
            // "you already have a reservation in that period" five times
            // in a row. The sheet normally prevents this; this is the
            // half that does not depend on the sheet being right.
            setState(() => _busy = false);
            AppSnack.info(
              context,
              l10n?.spaceAlreadyCheckedInHere ??
                  'You are already checked in here. Choose Check out to '
                      'leave the seat.',
              replace: true,
            );
            return;
          } else {
            await ref
                .read(reservationRepositoryProvider)
                .create(
                  workspaceId: workspace.id,
                  seatId: widget.seat.id,
                  startsAt: choice.start,
                  endsAt: choice.end,
                  checkIn: true,
                );
          }
        case SpaceAction.reserve:
          await ref
              .read(reservationRepositoryProvider)
              .create(
                workspaceId: workspace.id,
                seatId: widget.seat.id,
                startsAt: choice.start,
                endsAt: choice.end,
                checkIn: choice.checkInNow,
              );
        case SpaceAction.checkOut:
          final active = _myActiveCheckIn(reservations, now, me?.id);
          if (active == null) {
            setState(() => _busy = false);
            AppSnack.error(
              context,
              l10n?.kioskNotCheckedIn ??
                  'No active check-in found — the plan may have just '
                      'updated.',
              replace: true,
            );
            return;
          }
          await ref.read(reservationRepositoryProvider).checkOut(active.id);
      }
    } catch (e, st) {
      TraceLogger.instance.error(
        'reservations',
        'space act failed',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      // Shared mapper — the blocked-by-other refusal keeps the sheet
      // open, where the message affordance already names the holder.
      AppSnack.error(
        context,
        bookingErrorText(
          l10n,
          e,
          l10n?.workspaceGenericError ??
              'Something went wrong. Please try again.',
          stepMinutes: _granularity.stepMinutes,
        ),
        replace: true,
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      l10n?.kioskDone ?? "Done — you're all set.",
      replace: true,
    );
    invalidateBookingData(ref);
  }

  Widget _footer(BuildContext context, SpaceActChoice choice) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.read(clockProvider).now();
    final me = ref.watch(myMemberProvider).value;
    final reservations = _dayReservations(now);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final mine = choice.action == SpaceAction.checkIn
        ? _myCheckInTarget(reservations, now, me?.id)
        : null;
    final blocking = _blocking(reservations, choice, me?.id);
    final name = blocking == null ? '' : (names[blocking.memberId] ?? '');
    // #814 — the confirm button obeys the gate the form already shows.
    // #1135 — and the member's own standing, which the gate cannot see.
    final ownRefusal = _ownStandingRefusal(choice, l10n);
    final refused = _refusalOf(choice) != null || ownRefusal != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mine != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n?.spaceYoursNow ?? 'Reserved by you for this slot.',
            key: const ValueKey('space-act-yours'),
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (ownRefusal != null) ...[
          const SizedBox(height: 8),
          Text(
            ownRefusal,
            key: const ValueKey('space-act-own-standing'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (blocking != null) ...[
          const SizedBox(height: 8),
          Text(
            '${blocking.status == ReservationStatus.checkedIn ? (l10n?.planOccupiedBy(name) ?? 'Occupied by $name') : (l10n?.planReservedBy(name) ?? 'Reserved by $name')}'
            ' · ${l10n?.planUntil(ref.watch(appFormatProvider).time(blocking.endsAt)) ?? 'until ${ref.watch(appFormatProvider).time(blocking.endsAt)}'}',
            key: const ValueKey('space-act-blocked'),
            style: theme.textTheme.bodySmall,
          ),
          if (canMessageReserver(ref, blocking)) ...[
            const SizedBox(height: 8),
            MessageReserverButton(
              widgetKey: const ValueKey('space-act-message'),
              blocking: blocking,
              name: name,
              spaceName: widget.title,
            ),
          ],
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('space-act-confirm'),
          onPressed: _busy || refused ? null : () => _confirm(choice),
          icon: const Icon(Icons.check),
          label: Text(l10n?.kioskBadgeConfirm ?? 'Confirm'),
        ),
      ],
    );
  }

  /// #1135 — why THIS member cannot do THIS to THIS seat, before they
  /// tap. The booking gate answers about the window and the space; this
  /// answers about the member's own standing, which the gate never sees.
  ///
  /// Returning a sentence rather than a bool: "Confirm is greyed out" is
  /// not an answer, and the sequence this fixes had somebody tapping an
  /// enabled button five times.
  String? _ownStandingRefusal(SpaceActChoice choice, AppLocalizations? l10n) {
    if (choice.action == SpaceAction.checkOut) return null;
    final now = ref.read(clockProvider).now();
    final me = ref.read(myMemberProvider).value;
    final live = _myLiveCheckInHere(_dayReservations(now), now, me?.id);
    // Only a choice that OVERLAPS the live check-in is impossible. A
    // member sitting here this morning may reserve this seat for the
    // afternoon; enforce_one_place counts overlaps and nothing else, and
    // so must this.
    if (live == null || !live.coversRange(choice.start, choice.end)) {
      return null;
    }
    return l10n?.spaceAlreadyCheckedInHere ??
        'You are already checked in here. Choose Check out to leave the '
            'seat.';
  }

  /// The gate's answer for [choice] (null while the feature is off).
  BookingRefusal? _refusalOf(SpaceActChoice choice) {
    if (choice.action == SpaceAction.checkOut) return null;
    final gate = bookingGateOf(ref);
    return gate?.refusalFor(
      start: choice.start,
      end: choice.end,
      walkUp: choice.action == SpaceAction.checkIn || choice.checkInNow,
      seat: widget.seat,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider).now();
    final gate = bookingGateOf(ref, watch: true);
    return SingleChildScrollView(
      child: SheetShell(
        title: widget.title,
        children: [
          SpaceActForm(
            granularity: _granularity,
            now: now,
            // #1135 — already sitting here? Then the move is to leave.
            // Opening on "Check in" put the member one tap from a
            // request that could not succeed.
            initialAction:
                _myLiveCheckInHere(
                      _dayReservations(now),
                      now,
                      ref.read(myMemberProvider).value?.id,
                    ) !=
                    null
                ? SpaceAction.checkOut
                : null,
            footer: _footer,
            refusalOf: gate == null ? null : _refusalOf,
            refusalTextOf: gate == null
                ? null
                : (refusal) => bookingRefusalText(
                      l10n,
                      refusal,
                      policies: gate.policies,
                      stepMinutes: _granularity.stepMinutes,
                    ),
          ),
        ],
      ),
    );
  }
}
