// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/booking_policies.dart';
import 'booking_gate.dart';
import 'booking_refusal_codes.dart';

/// THE booking-failure → user-message mapper (maintainability audit:
/// this switch was pasted, and drifting, across four screens). Maps the
/// server's refusal codes to their localized explanations (#3810), and the
/// few refusals without a code of their own by their words; anything
/// unmapped falls back to [fallback].
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
  // #3810 — a booking refusal is read by its code (0739), never its words.
  final coded = bookingCodeText(l10n, error.code, error.details,
      stepMinutes: stepMinutes);
  if (coded != null) return coded;
  final message = error.message;
  // What still has no code of its own: the hierarchy guard keeps Postgres's
  // exclusion code (23P01), a taken seat is the exclusion constraint itself,
  // and the permission refusal is 42501 for every write.
  if (message.contains('that space is already reserved in that period')) {
    return l10n.bookingSpaceChainTaken;
  }
  if (message.contains('already reserved')) {
    return l10n.levelConflict;
  }
  if (message.contains('not allowed to make reservations')) {
    return l10n.bookingNotAllowedError;
  }
  return fallback;
}


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
  // #3810 — by its code (0739's DKK26, the hierarchy guard's 23P01); a taken
  // seat has no code of its own yet and is read by its words.
  return error.code == 'DKK26' ||
      error.code == '23P01' ||
      error.message.contains('already reserved');
}
