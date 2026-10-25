// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a KPI's figure is made of beyond its number: how it combines, which
// date places a record in a period, and which past it can speak for. The
// server registry carries the same wire names (kpi_registry_sql_test).
//
// Pure Dart: no Flutter, no l10n.
library;

/// How a KPI may be combined across a dimension or across time.
enum KpiAggregation {
  /// sum(numerator) / sum(denominator) over the whole scope.
  ratioOfSums,

  /// Additive over disjoint intervals and resources.
  sum,

  /// #2582 — a stock read at the end of the period (what is owed then):
  /// never summed over months; a longer period is its last month's value.
  lastAtCutoff;

  /// The wire name the server registry uses.
  String get wire => switch (this) {
    ratioOfSums => 'ratio_of_sums',
    sum => 'sum',
    lastAtCutoff => 'last_at_cutoff',
  };
}

/// Which date places a record in a period. Two figures on different bases
/// do not describe the same months even when their periods read alike: a
/// payment matched in March may have reached the bank in February.
enum KpiDateBasis {
  /// The booked time itself, cut at the period's edges.
  reservationTime,

  /// The month an invoice belongs to.
  invoiceMonth,

  /// When a payment was matched to an invoice: not the bank's date.
  paymentMatchedAt,

  /// The day a payment out was reported paid.
  paymentReportedPaid,

  /// A purchase document's own date.
  documentDate,

  /// The day a contract occurrence falls due.
  occurrenceDue,

  /// The periods of confirmed book values.
  bookValuePeriod,

  /// A stock as it stands at the end of the period.
  periodEnd,

  /// Now: the period only says which month is the current one.
  currentState;

  String get wire => switch (this) {
    reservationTime => 'reservation_time',
    invoiceMonth => 'invoice_month',
    paymentMatchedAt => 'payment_matched_at',
    paymentReportedPaid => 'payment_reported_paid',
    documentDate => 'document_date',
    occurrenceDue => 'occurrence_due',
    bookValuePeriod => 'book_value_period',
    periodEnd => 'period_end',
    currentState => 'current_state',
  };
}

/// Which past a figure can speak for: what the server keeps decides whether
/// a past period is the past as it was, or the past read from today's
/// records.
enum KpiCoverage {
  /// From the start of the recorded history on, as it was then; earlier
  /// time is not recorded.
  recordedHistory,

  /// Every record the source holds, as it stands now: a past period is
  /// "past period, current records".
  currentRecords,

  /// Only what confirmed values cover; the rest is unknown, never 0.
  confirmedValues,

  /// Today only; a past period has no recorded value.
  currentStateOnly;

  String get wire => switch (this) {
    recordedHistory => 'recorded_history',
    currentRecords => 'current_records',
    confirmedValues => 'confirmed_values',
    currentStateOnly => 'current_state_only',
  };
}
