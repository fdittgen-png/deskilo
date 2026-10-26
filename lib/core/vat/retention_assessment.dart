// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What the server's retention assessment says about records that would go:
// keep them, have a person review the rule, or the period has ended. It is
// never a permission to delete; the server decides, this only reads it.
import '../data/json_reader.dart';

/// What may become of a set of records under retention.
enum RetentionDisposition {
  /// A clock still runs, or a hold is in place.
  retain('retain'),

  /// No clock runs, but a rule is unconfirmed, the shared default, missing,
  /// without its trigger date, or the issuer's fiscal calendar is assumed.
  reviewRequired('review_required'),

  /// Confirmed rules only, every clock ended, no hold: the existing erasure
  /// review may consider them. Nothing is deleted by this.
  eligible('eligible_for_erasure_review');

  const RetentionDisposition(this.wire);

  final String wire;

  static RetentionDisposition? fromWire(String? wire) {
    for (final d in values) {
      if (d.wire == wire) return d;
    }
    return null;
  }
}

/// The assessment of one store's records (`retention_assess_records`): the
/// strictest disposition across their issuers, the latest end, the rule
/// that sets it and the reasons for a review.
class RetentionAssessment {
  const RetentionAssessment({
    required this.disposition,
    this.retainUntil,
    this.indefinite = false,
    this.ruleSource,
    this.holdReasons = const [],
    this.reasons = const [],
  });

  /// Null when the JSON carries no disposition: there is nothing to keep.
  static RetentionAssessment? fromJson(Object? raw) {
    if (raw == null) return null;
    final r = JsonReader.of(raw, context: 'retention');
    final disposition = RetentionDisposition.fromWire(r.stringOrNull('disposition'));
    if (disposition == null) return null;
    return RetentionAssessment(
      disposition: disposition,
      retainUntil: r.dateTimeOrNull('retain_until'),
      indefinite: r.isTrue('indefinite'),
      ruleSource: r.objectOrNull('rule')?.stringOrNull('source'),
      holdReasons: [
        for (final reason in r.objects('holds', (h) => h.stringOrNull('reason')))
          ?reason,
      ],
      reasons: r.strings('reasons'),
    );
  }

  final RetentionDisposition disposition;

  /// The first day the latest record may go; null when no clock is known.
  final DateTime? retainUntil;

  /// A hold keeps the records with no end date.
  final bool indefinite;

  /// The statute or setting behind [retainUntil].
  final String? ruleSource;
  final List<String> holdReasons;

  /// Why a person reviews the rule (`unconfirmed`, `default_rule`, ...).
  final List<String> reasons;

  /// The stricter of [a] and [b]: a hold over a clock over a review over an
  /// ended period, the later end between equals.
  static RetentionAssessment? strictest(RetentionAssessment? a, RetentionAssessment? b) {
    if (a == null) return b;
    if (b == null) return a;
    int rank(RetentionAssessment x) =>
        x.indefinite ? 3 : switch (x.disposition) {
          RetentionDisposition.retain => 2,
          RetentionDisposition.reviewRequired => 1,
          RetentionDisposition.eligible => 0,
        };
    if (rank(a) != rank(b)) return rank(a) > rank(b) ? a : b;
    final ua = a.retainUntil, ub = b.retainUntil;
    if (ua == null) return b;
    if (ub == null) return a;
    return ub.isAfter(ua) ? b : a;
  }
}
