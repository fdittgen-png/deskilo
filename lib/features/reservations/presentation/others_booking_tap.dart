// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Someone else's booking on a seat: admin actions, a message to the
// holder, or who has it until when. The plan's tap on a reserved or
// occupied seat opens it, and so does that booking's row in the seat-day
// sheet (#1813) — one answer, whichever way the booking was reached.
part of 'reserve_seat_actions.dart';

/// [state] says whether the seat reads occupied or reserved; [isLive] and
/// [canCheckInForOthers] decide whether a check-in for them is offered.
Future<void> _openOthersBooking(
  BuildContext context,
  WidgetRef ref, {
  required Seat seat,
  required Reservation other,
  required SeatState state,
  required bool isLive,
  required bool canCheckInForOthers,
  required BookingGranularity granularity,
}) async {
  final l10n = AppLocalizations.of(context);
  final names = ref.read(memberNamesProvider).value ?? const {};
  final name = names[other.memberId] ?? '';
  // #687 — admin powers on another member's seat came with the
  // Plan tab's job: check them in while they are standing there
  // (#408 — live only, window open, bookForOthers gate) and
  // overrule, which removes the reservation with a notification
  // (#412 — any admin, any time). The server re-checks both.
  final windowOpen = other.checkInWindowOpen(
    ref.read(clockProvider).now(),
    granularity: granularity,
  );
  final offerCheckIn = isLive && canCheckInForOthers && windowOpen;
  if (!offerCheckIn) {
    traceCheckInNotOffered(
      seat: seat,
      other: other,
      live: isLive,
      mayCheckInOthers: canCheckInForOthers,
      windowOpen: windowOpen,
    );
  }
  final canOverrule = ref.read(myMemberProvider).value?.canAdminister ?? false;
  // #814 — admins may END a running check-in where the owner's
  // `admin_check_out` policy allows it (gate on).
  final offerCheckOut =
      canOverrule &&
      other.status == ReservationStatus.checkedIn &&
      (bookingGateOf(ref)?.policies.adminCheckOut ?? false);
  if (offerCheckIn || canOverrule) {
    await runAdminSeatActions(
      context,
      ref,
      seat: seat,
      other: other,
      name: name,
      offerCheckIn: offerCheckIn,
      offerCheckOut: offerCheckOut,
      stepMinutes: granularity.stepMinutes,
      // #622 — admins get the message affordance ON TOP of their
      // admin actions.
      offerMessage: canMessageReserver(ref, other),
    );
    return;
  }
  final template = state == SeatState.occupied
      ? (l10n?.planOccupiedBy(name) ?? 'Occupied by $name')
      : (l10n?.planReservedBy(name) ?? 'Reserved by $name');
  // #908 — display, not wall: a member who asked to read hours in
  // their own timezone must get them here too.
  final until = ref.read(appFormatProvider).time(other.endsAt);
  final infoLine = '$template · ${l10n?.planUntil(until) ?? 'until $until'}';
  // #622 — a REGULAR member can message the holder instead of
  // reading a dead-end snack; the flag off keeps the plain line.
  if (canMessageReserver(ref, other)) {
    await showBlockedSpaceSheet(
      context,
      ref,
      title: seat.name,
      infoLine: infoLine,
      blocking: other,
      name: name,
      spaceName: seat.name,
    );
    return;
  }
  AppSnack.info(context, infoLine, replace: true);
}
