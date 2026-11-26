// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- the cash drawer's words: what a refusal of the till sessions says, by the code and the reason the server gives
// (never its sentence), and what a problem with a typed value says.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

import '../../../../core/codes/dk_code.dart';
import '../../../../core/trace/refusal_text.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/till_drawer_rules.dart';

/// The `reason` the server puts in the detail of a till refusal, or null when it gives none.
String? _drawerRefusalReason(Object error) {
  final raw = refusalCodeOf(error).details;
  if (raw == null) return null;
  try {
    return JsonReader.of(jsonDecode(raw), context: 'till_refusal').stringOrNull('reason');
  } on Object catch (e, st) {
    // a detail that is not our JSON is no hint: the generic words stand
    TraceLogger.instance.warn('money', 'a till refusal detail is not readable', error: e, stackTrace: st);
    return null;
  }
}

/// The name of the till a refusal names (`name` in its detail), or empty.
String _drawerRefusalName(Object error) {
  final raw = refusalCodeOf(error).details;
  if (raw == null) return '';
  try {
    return JsonReader.of(jsonDecode(raw), context: 'till_refusal').stringOr('name');
  } on Object catch (e, st) {
    // a detail that is not our JSON names no till: the generic words stand
    TraceLogger.instance.warn('money', 'a till refusal detail is not readable', error: e, stackTrace: st);
    return '';
  }
}

/// Whether [error] says the count differs and needs its reason.
bool drawerAsksDifferenceReason(Object error) => refusalCodeOf(error).code == DkCode.dkl13 && _drawerRefusalReason(error) == 'difference_reason';

/// The specific words of a till refusal, or null when the code and reason have none of their own.
String? drawerRefusalText(AppLocalizations l10n, Object error) {
  final code = refusalCodeOf(error).code;
  final reason = _drawerRefusalReason(error);
  return switch ((code, reason)) {
    (DkCode.dkl12, 'till_open_first') => l10n.tillDrawerRefusalOpenFirst,
    (DkCode.dkl12, 'already_open') => l10n.tillDrawerRefusalAlreadyOpen,
    (DkCode.dkl12, 'till_unknown') => l10n.tillDrawerRefusalTillUnknown,
    (DkCode.dkl12, 'session_unknown' || 'closed') => l10n.tillDrawerRefusalSessionGone,
    (DkCode.dkl12, 'name_taken') => l10n.tillDrawerRefusalNameTaken,
    (DkCode.dkl12, 'selling_place_unknown') => l10n.tillDrawerRefusalSellingPlace,
    (DkCode.dkl13, 'denominations') => l10n.tillDrawerRefusalDenominations,
    (DkCode.dkl13, 'reason_unknown') => l10n.tillDrawerRefusalReasonUnknown,
    (DkCode.dkl13, 'above_limit') => l10n.tillDrawerRefusalAboveLimit,
    (DkCode.dkl13, 'difference_reason') => l10n.tillDrawerRefusalDifference,
    (DkCode.dkl14, 'till_open') => l10n.tillDayRefusalTillOpen(_drawerRefusalName(error)),
    (DkCode.dkl14, 'day_closed') => l10n.tillDayRefusalClosed,
    (DkCode.dkl14, 'nothing_to_close') => l10n.tillDayRefusalNothing,
    (DkCode.dkl14, 'future') => l10n.tillDayRefusalFuture,
    _ => null,
  };
}

/// What [problem] says: the till's own words for the reason, the server's refusal family, or a plain failure.
String drawerProblemText(AppLocalizations l10n, Object problem) => drawerRefusalText(l10n, problem) ?? knownRefusalText(l10n, problem) ?? l10n.tillDrawerFailed;

/// What a problem with a typed value says under its field.
String _drawerFieldText(AppLocalizations l10n, DrawerProblem problem) => switch (problem) {
  DrawerProblem.nameMissing => l10n.tillDrawerNameMissing,
  DrawerProblem.amountInvalid => l10n.tillDrawerAmountInvalid,
  DrawerProblem.amountZero => l10n.tillDrawerAmountZero,
  DrawerProblem.reasonMissing => l10n.tillDrawerEntryReasonMissing,
  DrawerProblem.bankedAboveCounted => l10n.tillDrawerBankedAbove,
  DrawerProblem.differenceReasonMissing => l10n.tillDrawerDifferenceReasonMissing,
  DrawerProblem.denominationsIncomplete => l10n.tillDrawerDenomIncomplete,
};

/// The problems of a form as [FieldErrors]: the field's key, then the words.
Map<String, String> drawerFieldErrors(AppLocalizations l10n, Map<DrawerField, DrawerProblem> problems) => {
  for (final e in problems.entries) e.key.name: _drawerFieldText(l10n, e.value),
};
