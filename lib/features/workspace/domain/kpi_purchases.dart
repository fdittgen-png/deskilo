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

import '../../../core/data/json_reader.dart';
import 'kpi_contract.dart';
import 'kpi_costs.dart';

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

/// The purchase figures, in catalogue order.
const purchaseKpis = <KpiDefinition>[
  _apOutstandingKpi,
  _memberReimbursementsDueKpi,
  _pendingReviewsKpi,
  _recordedOutflowsKpi,
  ...costKpis,
];

/// What `kpi_purchases_summary` returned for the whole months
/// [fromMonth, toMonth], typed. A missing amount is null, never 0.
class PurchaseSummaryKpi {
  const PurchaseSummaryKpi({
    required this.fromMonth,
    required this.toMonth,
    required this.currency,
    required this.apOutstandingMinor,
    required this.memberDueMinor,
    required this.pendingCount,
    required this.pendingMinor,
    required this.outflowsMinor,
    required this.outflows,
    required this.quality,
    required this.reasons,
    required this.computedAt,
  });

  final String fromMonth;
  final String toMonth;
  final String currency;
  final int? apOutstandingMinor;
  final int? memberDueMinor;
  final int pendingCount;
  final int? pendingMinor;
  final int? outflowsMinor;

  /// How many payments out the outflows are made of.
  final int outflows;
  final Set<KpiQuality> quality;
  final List<String> reasons;
  final DateTime computedAt;

  /// The figure [moduleId] shows (minor units, or a count).
  int? figure(String moduleId) => switch (moduleId) {
    'purchases.ap_outstanding' => apOutstandingMinor,
    'purchases.member_reimbursements_due' => memberDueMinor,
    'purchases.pending_reviews' => pendingCount,
    _ => outflowsMinor,
  };
}

/// Parses the RPC's jsonb. An amount that cannot travel exactly makes the
/// figures unavailable (`amount_not_exact`), never a rounded number.
PurchaseSummaryKpi purchaseSummaryFromJson(Map<String, Object?> json) {
  final r = JsonReader(json, context: 'kpi_purchases_summary');
  final quality = r.strings('quality');
  final reasons = r.strings('reasons');
  final ap = exactMinor(r.raw('ap_outstanding_minor'));
  final member = exactMinor(r.raw('member_due_minor'));
  final pending = exactMinor(r.raw('pending_minor'));
  final out = exactMinor(r.raw('outflows_minor'));
  final inexact =
      ap == null || member == null || pending == null || out == null;
  final currency = r.stringOr('currency');
  final pendingCount = r.integer('pending_count');
  final outflows = r.integer('outflows');
  if (pendingCount < 0 || outflows < 0) {
    throw const FormatException('Invalid purchase count');
  }
  return PurchaseSummaryKpi(
    fromMonth: r.stringOr('from'),
    toMonth: r.stringOr('to'),
    currency: currency,
    apOutstandingMinor: ap,
    memberDueMinor: member,
    pendingCount: pendingCount,
    pendingMinor: pending,
    outflowsMinor: out,
    outflows: outflows,
    quality: {
      for (final q in quality) kpiQualityOf(q) ?? KpiQuality.unavailable,
      if (inexact || currency.isEmpty) KpiQuality.unavailable,
    },
    reasons: [...reasons, if (inexact) 'amount_not_exact'],
    computedAt: r.dateTime('computed_at'),
  );
}

/// Reads the purchase figures (#2582). Every call is authorized there.
abstract interface class PurchaseKpiRepository {
  /// The figures of the whole months [fromMonth, toMonth] (`YYYY-MM`).
  Future<PurchaseSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  });
}

/// #2582 C2 — what `kpi_costs_summary` returned for the whole months
/// [fromMonth, toMonth], typed. A missing amount is null, never 0.
class CostSummaryKpi {
  const CostSummaryKpi({
    required this.fromMonth,
    required this.toMonth,
    required this.currency,
    required this.operatingCostsMinor,
    required this.acquisitionsMinor,
    required this.netSalesMinor,
    required this.contributionMinor,
    required this.unresolvedLines,
    required this.unqualifiedLines,
    required this.bookDepreciationMinor,
    required this.afterDepreciationMinor,
    required this.unbilledMinor,
    required this.unbilledOverdueMinor,
    required this.unbilledUpcomingMinor,
    required this.forecastMinor,
    required this.quality,
    required this.reasons,
    required this.computedAt,
  });

  final String fromMonth;
  final String toMonth;
  final String currency;
  final int? operatingCostsMinor;

  /// Null while the equipment register is off: unavailable, never 0.
  final int? acquisitionsMinor;
  final int? netSalesMinor;
  final int? contributionMinor;

  /// Lines nobody classified (left out), and operating lines whose
  /// recoverable share is not qualified (counted at their gross).
  final int unresolvedLines;
  final int unqualifiedLines;

  /// Null unless confirmed book values cover the months exactly.
  final int? bookDepreciationMinor;
  final int? afterDepreciationMinor;

  /// What the contracts still expect in the months; null without a lease
  /// or a rented room. Overdue (due before today) and upcoming apart.
  final int? unbilledMinor;
  final int? unbilledOverdueMinor;
  final int? unbilledUpcomingMinor;

  /// Owed to suppliers at the end of the months plus what the contracts
  /// still expect in them; null without a lease or a rented room.
  final int? forecastMinor;
  final Set<KpiQuality> quality;
  final List<String> reasons;
  final DateTime computedAt;

  /// The figure [moduleId] shows, in minor units.
  int? figure(String moduleId) => switch (moduleId) {
    'purchases.operating_costs' => operatingCostsMinor,
    'assets.acquisitions' => acquisitionsMinor,
    'assets.book_depreciation' => bookDepreciationMinor,
    'finance.contribution_after_depreciation' => afterDepreciationMinor,
    'purchases.unbilled_commitments' => unbilledMinor,
    'purchases.forecast_outflows' => forecastMinor,
    _ => contributionMinor,
  };
}

/// Parses `kpi_costs_summary`'s jsonb; an inexact amount is unknown.
CostSummaryKpi costSummaryFromJson(Map<String, Object?> json) {
  final r = JsonReader(json, context: 'kpi_costs_summary');
  final costs = exactMinor(r.raw('operating_costs_minor'));
  final sales = exactMinor(r.raw('net_sales_minor'));
  final contribution = exactMinor(r.raw('contribution_minor'));
  // Each of these may be null on purpose (unknown); only a present value
  // that cannot travel exactly is inexact.
  final optional = {
    for (final key in const [
      'acquisitions_minor',
      'book_depreciation_minor',
      'after_depreciation_minor',
      'unbilled_minor',
      'unbilled_overdue_minor',
      'unbilled_upcoming_minor',
      'forecast_minor',
    ])
      key: r.raw(key),
  };
  int? opt(String key) => exactMinor(optional[key]);
  final inexact =
      costs == null ||
      sales == null ||
      contribution == null ||
      optional.entries.any((e) => e.value != null && opt(e.key) == null);
  final currency = r.stringOr('currency');
  return CostSummaryKpi(
    fromMonth: r.stringOr('from'),
    toMonth: r.stringOr('to'),
    currency: currency,
    operatingCostsMinor: costs,
    acquisitionsMinor: opt('acquisitions_minor'),
    netSalesMinor: sales,
    contributionMinor: contribution,
    unresolvedLines: r.integer('unresolved_lines'),
    unqualifiedLines: r.integer('unqualified_lines'),
    bookDepreciationMinor: opt('book_depreciation_minor'),
    afterDepreciationMinor: opt('after_depreciation_minor'),
    unbilledMinor: opt('unbilled_minor'),
    unbilledOverdueMinor: opt('unbilled_overdue_minor'),
    unbilledUpcomingMinor: opt('unbilled_upcoming_minor'),
    forecastMinor: opt('forecast_minor'),
    quality: {
      for (final q in r.strings('quality'))
        kpiQualityOf(q) ?? KpiQuality.unavailable,
      if (inexact || currency.isEmpty) KpiQuality.unavailable,
    },
    reasons: [...r.strings('reasons'), if (inexact) 'amount_not_exact'],
    computedAt: r.dateTime('computed_at'),
  );
}

/// Reads the cost figures (#2582 C2). Every call is authorized there.
abstract interface class CostKpiRepository {
  /// The figures of the whole months [fromMonth, toMonth] (`YYYY-MM`).
  Future<CostSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  });
}

/// No server to read the costs from (the demonstration).
class UnavailableCostKpiRepository implements CostKpiRepository {
  const UnavailableCostKpiRepository();

  @override
  Future<CostSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => throw const KpiUnavailable('no server in this mode');
}
