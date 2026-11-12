// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3810 (part of #3657, i18n I11b) -- a booking refusal is read by its code
// (0739), never by its sentence: the server raises a DKK errcode and, when
// the refusal names a value, that value as JSON in DETAIL. Rewording a
// server message can no longer silently break a translation.
import 'dart:convert';

import '../../../l10n/app_localizations.dart';

/// The words of a booking refusal's [code], or null for a code that is not a
/// booking refusal. [details] is the server's DETAIL (JSON); [stepMinutes] is
/// the grid the screen knows, when the server named none.
String? bookingCodeText(
  AppLocalizations l10n,
  String? code,
  Object? details, {
  int? stepMinutes,
}) {
  final words = _words[code];
  if (words == null) return null;
  final values = _detail(details);
  return words(l10n, (String key) => values[key] as int?, stepMinutes);
}

typedef _Words = String Function(
  AppLocalizations l10n,
  int? Function(String key) value,
  int? stepMinutes,
);

/// Every code 0739 issues, with its words (DKK14 and DKK24 are not issued).
final Map<String, _Words> _words = {
  'DKK01': (l, _, _) => l.planClosedDayError,
  'DKK02': (l, _, _) => l.quotaExceededError,
  'DKK03': (l, _, _) => l.reservationLimitError,
  'DKK04': (l, _, _) => l.planHalfDayError,
  'DKK05': (l, _, _) => l.planFullDayError,
  'DKK06': (l, v, step) => l.planSlotError(v('minutes') ?? step ?? 15),
  'DKK07': (l, _, _) => l.planSeatBlocked,
  'DKK08': (l, v, _) => l.bookingHorizonError(v('days') ?? 0),
  'DKK09': (l, v, _) => l.bookingTooShortError(v('minutes') ?? 0),
  'DKK10': (l, v, _) => l.bookingTooLongError(v('minutes') ?? 0),
  'DKK11': (l, _, _) => l.bookingPastError,
  'DKK12': (l, _, _) => l.bookingWalkUpTodayError,
  'DKK13': (l, _, _) => l.bookingSameDayError,
  'DKK15': (l, _, _) => l.bookingOutsideWalkUpError,
  'DKK16': (l, _, _) => l.bookingOutsideOffError,
  'DKK17': (l, _, _) => l.planCheckInNotYetError,
  'DKK18': (l, _, _) => l.planCheckInOverError,
  'DKK19': (l, _, _) => l.bookingOnePlace,
  'DKK20': (l, _, _) => l.bookingCheckedInElsewhere,
  'DKK21': (l, _, _) => l.levelNotAllowed,
  'DKK22': (l, _, _) => l.spaceNotWholeBookable,
  'DKK23': (l, _, _) => l.levelFeatureOff,
  'DKK25': (l, _, _) => l.bookingNoLongerCheckedIn,
  'DKK26': (l, _, _) => l.levelConflict,
  'DKK27': (l, _, _) => l.bookingMembershipPaused,
  'DKK28': (l, _, _) => l.bookingNotAMember,
  'DKK29': (l, _, _) => l.bookingNotYours,
  'DKK30': (l, _, _) => l.bookingNotCancellable,
  'DKK31': (l, _, _) => l.bookingRunningKeepsStart,
  'DKK32': (l, _, _) => l.bookingEndMustLieAhead,
  'DKK33': (l, _, _) => l.bookingOnlyUpcoming,
  'DKK34': (l, v, _) => l.bookingSeriesTooLong(v('days') ?? 0),
  'DKK35': (l, _, _) => l.bookingAdminNoLevel,
  'DKK36': (l, _, _) => l.bookingNoLongerReserved,
};

/// The refusal's values: DETAIL read as a JSON object, or none.
Map<String, Object?> _detail(Object? details) {
  if (details is Map) {
    return {for (final e in details.entries) '${e.key}': e.value};
  }
  if (details is! String || details.isEmpty) return const {};
  try {
    final decoded = jsonDecode(details);
    return decoded is Map
        ? {for (final e in decoded.entries) '${e.key}': e.value}
        : const {};
  } on FormatException {
    // trace-exempt: a DETAIL that is not JSON names no value.
    return const {};
  }
}
