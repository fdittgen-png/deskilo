// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/dk_code.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/booking_policies.dart';
import '../domain/booking_gate.dart';
import '../domain/reservation_refusal.dart';

export '../domain/reservation_refusal.dart'
    show ReservationRefusalKind, ReservationRefused, isBlockedByOtherError;

/// THE booking-failure → user-message mapper (maintainability audit: this
/// switch was pasted, and drifting, across four screens). Maps the server's
/// refusal (read once at the data boundary, #4156: a [ReservationRefused]) to
/// its localized explanation (#3810); anything the app does not know, or that
/// is not a refusal, falls back to [fallback]. The words live here, not in the
/// domain, and never come from the server's text.
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
  if (error is! ReservationRefused) return fallback;
  return _refusalWords(l10n, error.refusal, stepMinutes) ?? fallback;
}

/// The words of a server refusal, or null for one the app does not read.
/// [stepMinutes] is the grid the screen knows, when the server named none.
String? _refusalWords(
  AppLocalizations l10n,
  ReservationRefusal refusal,
  int? stepMinutes,
) => switch (refusal.kind) {
  ReservationRefusalKind.coded => _words[refusal.code]?.call(
    l10n,
    refusal.minutes,
    refusal.days,
    stepMinutes,
  ),
  ReservationRefusalKind.spaceChainTaken => l10n.bookingSpaceChainTaken,
  ReservationRefusalKind.alreadyReserved => l10n.levelConflict,
  ReservationRefusalKind.notAllowed => l10n.bookingNotAllowedError,
  ReservationRefusalKind.badgeRejected ||
  ReservationRefusalKind.notCheckedIn ||
  ReservationRefusalKind.unknown => null,
};

typedef _Words = String Function(
  AppLocalizations l10n,
  int? minutes,
  int? days,
  int? step,
);

/// Every code 0739 issues, with its words (DKK14 and DKK24 are not issued).
final Map<String, _Words> _words = {
  DkCode.dkk01: (l, _, _, _) => l.planClosedDayError,
  DkCode.dkk02: (l, _, _, _) => l.quotaExceededError,
  DkCode.dkk03: (l, _, _, _) => l.reservationLimitError,
  DkCode.dkk04: (l, _, _, _) => l.planHalfDayError,
  DkCode.dkk05: (l, _, _, _) => l.planFullDayError,
  DkCode.dkk06: (l, m, _, step) => l.planSlotError(m ?? step ?? 15),
  DkCode.dkk07: (l, _, _, _) => l.planSeatBlocked,
  DkCode.dkk08: (l, _, d, _) => l.bookingHorizonError(d ?? 0),
  DkCode.dkk09: (l, m, _, _) => l.bookingTooShortError(m ?? 0),
  DkCode.dkk10: (l, m, _, _) => l.bookingTooLongError(m ?? 0),
  DkCode.dkk11: (l, _, _, _) => l.bookingPastError,
  DkCode.dkk12: (l, _, _, _) => l.bookingWalkUpTodayError,
  DkCode.dkk13: (l, _, _, _) => l.bookingSameDayError,
  DkCode.dkk15: (l, _, _, _) => l.bookingOutsideWalkUpError,
  DkCode.dkk16: (l, _, _, _) => l.bookingOutsideOffError,
  DkCode.dkk17: (l, _, _, _) => l.planCheckInNotYetError,
  DkCode.dkk18: (l, _, _, _) => l.planCheckInOverError,
  DkCode.dkk19: (l, _, _, _) => l.bookingOnePlace,
  DkCode.dkk20: (l, _, _, _) => l.bookingCheckedInElsewhere,
  DkCode.dkk21: (l, _, _, _) => l.levelNotAllowed,
  DkCode.dkk22: (l, _, _, _) => l.spaceNotWholeBookable,
  DkCode.dkk23: (l, _, _, _) => l.levelFeatureOff,
  DkCode.dkk25: (l, _, _, _) => l.bookingNoLongerCheckedIn,
  DkCode.dkk26: (l, _, _, _) => l.levelConflict,
  DkCode.dkk27: (l, _, _, _) => l.bookingMembershipPaused,
  DkCode.dkk28: (l, _, _, _) => l.bookingNotAMember,
  DkCode.dkk29: (l, _, _, _) => l.bookingNotYours,
  DkCode.dkk30: (l, _, _, _) => l.bookingNotCancellable,
  DkCode.dkk31: (l, _, _, _) => l.bookingRunningKeepsStart,
  DkCode.dkk32: (l, _, _, _) => l.bookingEndMustLieAhead,
  DkCode.dkk33: (l, _, _, _) => l.bookingOnlyUpcoming,
  DkCode.dkk34: (l, _, d, _) => l.bookingSeriesTooLong(d ?? 0),
  DkCode.dkk35: (l, _, _, _) => l.bookingAdminNoLevel,
  DkCode.dkk36: (l, _, _, _) => l.bookingNoLongerReserved,
};

/// #814 — the SAME sentences, for a refusal the client foresaw. A
/// surface that asks the gate before acting prints exactly what the
/// server would have answered, so nobody learns two vocabularies.
String bookingRefusalText(
  AppLocalizations l10n,
  BookingRefusal refusal, {
  required BookingPolicies policies,
  int? stepMinutes,
}) => switch (refusal) {
  BookingRefusal.closedDay => l10n.planClosedDayError,
  BookingRefusal.seatBlocked => l10n.planSeatBlocked,
  BookingRefusal.beyondHorizon => l10n.bookingHorizonError(
    policies.advanceHorizonDays,
  ),
  BookingRefusal.tooShort => l10n.bookingTooShortError(
    policies.minDurationMinutes,
  ),
  BookingRefusal.tooLong => l10n.bookingTooLongError(
    policies.maxDurationMinutes,
  ),
  BookingRefusal.past => l10n.bookingPastError,
  BookingRefusal.walkUpNotToday => l10n.bookingWalkUpTodayError,
  BookingRefusal.crossesMidnight => l10n.bookingSameDayError,
  BookingRefusal.outsideHoursOff => l10n.bookingOutsideOffError,
  BookingRefusal.outsideHoursAheadOnly => l10n.bookingOutsideWalkUpError,
};
