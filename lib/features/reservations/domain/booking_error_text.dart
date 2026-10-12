// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../members/domain/membership_errors.dart';
import '../../money/domain/quota_rules.dart';
import '../../workspace/domain/booking_granularity.dart';
import '../../workspace/domain/booking_policies.dart';
import '../../workspace/domain/workspace_availability.dart';
import 'booking_gate.dart';

/// THE booking-failure → user-message mapper (maintainability audit:
/// this switch was pasted, and drifting, across four screens). Maps the
/// server's pinned error substrings to their localized explanations;
/// anything unmapped falls back to [fallback].
///
/// Order matters once: quota before granularity, because 'half-day
/// quota' also contains the granularity substring 'half-day'.
String bookingErrorText(
  AppLocalizations l10n,
  Object error,
  String fallback, {
  int? stepMinutes,
}) {
  // #1241 — a dropped connection is not "something went wrong": the
  // request never reached the server, and the booking was not made.
  if (isTransientNetworkFailure(error)) {
    return l10n.errorOffline;
  }
  if (error is! PostgrestException) return fallback;
  final message = error.message;
  if (message.contains(WorkspaceClosedError.serverSubstring)) {
    return l10n.planClosedDayError;
  }
  if (message.contains(QuotaExceededError.serverSubstring)) {
    return l10n.quotaExceededError;
  }
  if (message.contains(ReservationLimitError.serverSubstring)) {
    return l10n.reservationLimitError;
  }
  if (message.contains(BookingGranularityError.serverSubstring)) {
    return l10n.planHalfDayError;
  }
  if (message.contains(BookingGranularityError.fullDayServerSubstring)) {
    return l10n.planFullDayError;
  }
  if (message.contains(BookingGranularityError.slotServerSubstring)) {
    final step = stepMinutes ?? 15;
    return l10n.planSlotError(step);
  }
  // #814 — the kiosk's seat-block refusal (kiosk_act) rendered generic.
  if (message.contains('seat is blocked')) {
    return l10n.planSeatBlocked;
  }
  // #649 — the three limits enforce_booking_rules coalesces (#814: they
  // rendered as "the seat may have just been taken").
  if (message.contains('beyond the advance-booking horizon')) {
    return l10n.bookingHorizonError(_leadingInt(message) ?? 0);
  }
  if (message.contains('below the minimum duration')) {
    return l10n.bookingTooShortError(_leadingInt(message) ?? 0);
  }
  if (message.contains('above the maximum duration')) {
    return l10n.bookingTooLongError(_leadingInt(message) ?? 0);
  }
  // #644 — a booking ends on the day it starts.
  if (message.contains('must end on the day it starts')) {
    return l10n.bookingSameDayError;
  }
  // #600 booking-policy refusals (migration 0116).
  if (message.contains('lies entirely in the past')) {
    return l10n.bookingPastError;
  }
  if (message.contains('must start today')) {
    return l10n.bookingWalkUpTodayError;
  }
  if (message.contains('stay within the working hours')) {
    return l10n.bookingOutsideHoursError;
  }
  // #634 outside-hours mode 'walkup_only' (migration 0120): the same
  // pinned substring plus 'spontaneous check-in' — checked FIRST, so
  // the member learns the door is only closed for booking AHEAD.
  if (message.contains('spontaneous check-in') &&
      message.contains('outside the opening hours')) {
    return l10n.bookingOutsideWalkUpError;
  }
  // #624 outside-hours mode 'off' (migration 0118, pinned substring).
  if (message.contains('outside the opening hours')) {
    return l10n.bookingOutsideOffError;
  }
  // Presence rule (#408, migration 0077): check-in only inside
  // [starts − 15 min, end).
  if (message.contains('check-in window not open yet')) {
    return l10n.planCheckInNotYetError;
  }
  if (message.contains('check-in window closed')) {
    return l10n.planCheckInOverError;
  }
  // One place at a time (#412, 0079 trigger + check-in guards).
  if (message.contains('you already have a reservation in that period')) {
    return l10n.bookingOnePlace;
  }
  if (message.contains('already checked in elsewhere')) {
    return l10n.bookingCheckedInElsewhere;
  }
  // Whole-space paths (0050/0057): grant refusals and occupancy
  // conflicts share these pinned substrings across office and level.
  if (message.contains('not allowed to reserve a level')) {
    return l10n.levelNotAllowed;
  }
  // #412: these two rendered as "Something went wrong" — the owner had
  // no way to learn WHICH toggle was missing.
  if (message.contains('not bookable as a whole')) {
    return l10n.spaceNotWholeBookable;
  }
  if (message.contains('level booking is not enabled')) {
    return l10n.levelFeatureOff;
  }
  // #1908 — the hierarchy guard (0325/0326): a seat and its whole desk,
  // office or level overlap. Before the level wording, which it contains.
  if (message.contains('that space is already reserved in that period')) {
    return l10n.bookingSpaceChainTaken;
  }
  // #1908 — a checkout that lost the race to another checkout or to the
  // day-end sweep: the reservation is already closed.
  if (message.contains('not checked in')) {
    return l10n.bookingNoLongerCheckedIn;
  }
  if (message.contains('reservations in that period') ||
      message.contains('already reserved') ||
      message.contains('reserved as a whole')) {
    return l10n.levelConflict;
  }
  // #1030 — membership refusals. create_reservation raises 'not an
  // active member' for a paused member and 'not a member of this
  // workspace' for one who was removed; both used to render as "the
  // seat may have just been taken", which blames a race the member
  // cannot win and hides the one thing an administrator can fix.
  if (message.contains(MembershipPausedError.serverSubstring)) {
    return l10n.bookingMembershipPaused;
  }
  if (message.contains(NotAMemberError.serverSubstring)) {
    return l10n.bookingNotAMember;
  }
  return fallback;
}

/// The number the server put in its message ('... of 90 days').
int? _leadingInt(String message) =>
    int.tryParse(RegExp(r'of (\d+) ').firstMatch(message)?.group(1) ?? '');

/// #814 — the SAME sentences, for a refusal the client foresaw. A
/// surface that asks the gate before acting prints exactly what the
/// server would have answered, so nobody learns two vocabularies.
String bookingRefusalText(
  AppLocalizations l10n,
  BookingRefusal refusal, {
  required BookingPolicies policies,
  int? stepMinutes,
}) =>
    switch (refusal) {
      BookingRefusal.closedDay =>
        l10n.planClosedDayError,
      BookingRefusal.seatBlocked =>
        l10n.planSeatBlocked,
      BookingRefusal.beyondHorizon =>
        l10n.bookingHorizonError(policies.advanceHorizonDays),
      BookingRefusal.tooShort =>
        l10n.bookingTooShortError(policies.minDurationMinutes),
      BookingRefusal.tooLong =>
        l10n.bookingTooLongError(policies.maxDurationMinutes),
      BookingRefusal.past =>
        l10n.bookingPastError,
      BookingRefusal.walkUpNotToday =>
        l10n.bookingWalkUpTodayError,
      BookingRefusal.crossesMidnight => l10n.bookingSameDayError,
      BookingRefusal.outsideHoursOff => l10n.bookingOutsideOffError,
      BookingRefusal.outsideHoursAheadOnly =>
        l10n.bookingOutsideWalkUpError,
    };

/// #622 — whether [error] is an occupancy refusal caused by ANOTHER
/// member's reservation (the pinned others-blocking substrings above;
/// 'you already have a reservation in that period' is the member's OWN
/// booking and deliberately not matched). Surfaces use this to offer
/// contacting the reserver.
bool isBlockedByOtherError(Object error) {
  if (error is! PostgrestException) return false;
  final message = error.message;
  return message.contains('reservations in that period') ||
      message.contains('already reserved') ||
      message.contains('reserved as a whole');
}
