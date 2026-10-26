// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../data/server_error.dart';
import '../vat/retention_assessment.dart';
import 'trace_logger.dart';

/// The SQLSTATE of a destructive step the server refused because the
/// records it would remove are still under retention.
const _retentionRefusalCode = 'DKE01';

/// The assessment a retention refusal carries, or null when [error] is not
/// one.
RetentionAssessment? retentionRefusalOf(Object error) {
  if (serverErrorCode(error) != _retentionRefusalCode) return null;
  final details = serverErrorDetails(error);
  if (details == null) return null;
  try {
    return RetentionAssessment.fromJson(jsonDecode(details));
  } on Exception catch (e, st) {
    TraceLogger.instance.warn('retention', 'unreadable retention refusal', error: e, stackTrace: st);
    return null;
  }
}

/// What [a] says about the records it covers, in the reader's language:
/// the hold, the day the rule ends, the review a person owes, or that the
/// period has ended.
String retentionAssessmentText(AppLocalizations l10n, RetentionAssessment a, String locale) {
  final until = a.retainUntil == null ? null : DateFormat.yMMMd(locale).format(a.retainUntil!);
  if (a.indefinite) return l10n.retentionKeptHold(a.holdReasons.join(' · '));
  return switch (a.disposition) {
    RetentionDisposition.retain when until != null =>
      l10n.retentionKeptUntil(until, a.ruleSource ?? l10n.retentionTitle),
    RetentionDisposition.retain || RetentionDisposition.reviewRequired =>
      until == null ? l10n.retentionKeptReview : l10n.retentionKeptReviewEnded(until),
    RetentionDisposition.eligible => l10n.retentionPeriodEnded,
  };
}
