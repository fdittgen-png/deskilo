// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C1 — the purchase side of the figures, on the KPI contract (#1918):
// what the space owes its suppliers and has to reimburse its members at the
// end of a period, what still waits for a review, and what it paid out in
// the period. The SERVER computes them (`kpi_purchases_summary`, 0527) from
// the purchase records themselves; this layer names what it returns.
//
//   * a stock (owed, to reimburse) is read at the end of the period's last
//     month, from what was dated by then — never a sum of months;
//   * a flow (paid out) is the payments reported inside the period;
//   * the review queue is the current one: no history of it is kept, so a
//     past period says so instead of guessing;
//   * a member's claim applied to an invoice is settled by that invoice,
//     never counted as owed as well as netted.
//
// Pure Dart: no Flutter, no l10n.
library;

import 'kpi_contract.dart';

const _apOutstandingKpi = KpiDefinition(
  id: 'purchases.ap_outstanding',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'at the end of the last month of [from, to] on the workspace '
      'calendar: approved supplier payables dated by then, less what was '
      'paid, credited or offset by then',
  dimensions: [],
  numerator: 'ap_outstanding_minor',
  denominator: '',
  aggregation: KpiAggregation.lastAtCutoff,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['purchases', 'the workspace currency'],
  minCohort: null,
);

const _memberReimbursementsDueKpi = KpiDefinition(
  id: 'purchases.member_reimbursements_due',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'at the end of the last month of [from, to]: members\' approved '
      'claims dated by then, less what was paid back or offset by then; '
      'a claim an invoice netted by then is settled',
  dimensions: [],
  numerator: 'member_due_minor',
  denominator: '',
  aggregation: KpiAggregation.lastAtCutoff,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['purchases', 'the workspace currency'],
  minCohort: null,
);

const _pendingReviewsKpi = KpiDefinition(
  id: 'purchases.pending_reviews',
  version: 1,
  unit: 'count',
  timeBasis:
      'now: the purchase documents waiting for a decision; a past period '
      'has no recorded queue',
  dimensions: [],
  numerator: 'pending_count',
  denominator: '',
  aggregation: KpiAggregation.lastAtCutoff,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['purchases'],
  minCohort: null,
);

const _recordedOutflowsKpi = KpiDefinition(
  id: 'cash.recorded_outflows',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the day a payment out was reported paid, whole months [from, to] on '
      'the workspace calendar; reversed and prepared payments left out',
  dimensions: [],
  numerator: 'outflows_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['purchases', 'recorded payments', 'the workspace currency'],
  minCohort: null,
);

/// The four, in catalogue order.
const purchaseKpis = <KpiDefinition>[
  _apOutstandingKpi,
  _memberReimbursementsDueKpi,
  _pendingReviewsKpi,
  _recordedOutflowsKpi,
];
