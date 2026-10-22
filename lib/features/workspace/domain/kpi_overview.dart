// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2583 — the overview's own figures, on the KPI contract (#1918): current
// state, read now, never a history the source does not keep.
//
//   * people.active_memberships_current — the memberships of the space that
//     are active today, each role included: memberships, not distinct
//     people across the network;
//   * sales.overdue_receivables — what members still owe on issued
//     invoices past their proven due date, by the dunning rules themselves
//     (credits, part payments and write-offs taken off); an invoice whose
//     due date is unknown, or that is on hold, is counted apart, never in
//     the overdue figure.
//
// The SERVER computes them (`kpi_memberships_current`,
// `kpi_overdue_receivables`, 0536). Pure Dart: no Flutter, no l10n.
library;

import '../../../core/data/json_reader.dart';
import 'kpi_contract.dart';

const _activeMembershipsKpi = KpiDefinition(
  id: 'people.active_memberships_current',
  version: 1,
  unit: 'count',
  timeBasis:
      'now: the memberships whose status is active, each role included; a '
      'past period has no recorded count',
  dimensions: [],
  numerator: 'active_memberships',
  denominator: '',
  aggregation: KpiAggregation.lastAtCutoff,
  permissions: ['viewAnalytics'],
  disclosure: KpiDisclosure.aggregateOperational,
  prerequisites: ['members'],
  minCohort: null,
);

const _overdueReceivablesKpi = KpiDefinition(
  id: 'sales.overdue_receivables',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'now: issued invoices past their proven due date, what is still '
      'collectible under the dunning rules; unknown due dates and holds '
      'apart',
  dimensions: [],
  numerator: 'overdue_minor',
  denominator: '',
  aggregation: KpiAggregation.lastAtCutoff,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['invoicing', 'the workspace currency'],
  minCohort: null,
);

/// The overview's figures, in catalogue order.
const overviewKpis = <KpiDefinition>[
  _activeMembershipsKpi,
  _overdueReceivablesKpi,
];

/// One current-state figure as the server returned it: a count, or an
/// amount in minor units with its count; null when unknown.
class OverviewFigure {
  const OverviewFigure({
    required this.value,
    required this.count,
    required this.currency,
    required this.quality,
    required this.reasons,
    required this.computedAt,
    this.unknownDueCount = 0,
    this.heldCount = 0,
  });

  final int? value;

  /// How many items the value is made of (invoices, memberships).
  final int count;
  final String currency;

  /// Overdue receivables only: invoices with no proven due date, and
  /// invoices on hold, counted apart and not in [value].
  final int unknownDueCount;
  final int heldCount;
  final Set<KpiQuality> quality;
  final List<String> reasons;
  final DateTime computedAt;
}

/// Parses `kpi_memberships_current` or `kpi_overdue_receivables`; an
/// amount that cannot travel exactly is unknown.
OverviewFigure overviewFigureFromJson(Map<String, Object?> json) {
  final r = JsonReader(json, context: 'kpi_overview');
  final raw = r.raw('value');
  final value = raw is int ? raw : exactMinor(raw);
  final inexact = raw != null && value == null;
  return OverviewFigure(
    value: value,
    count: r.integer('count'),
    currency: r.stringOr('currency'),
    unknownDueCount: r.intOrNull('unknown_due_count') ?? 0,
    heldCount: r.intOrNull('held_count') ?? 0,
    quality: {
      for (final q in r.strings('quality'))
        kpiQualityOf(q) ?? KpiQuality.unavailable,
      if (inexact || value == null) KpiQuality.unavailable,
    },
    reasons: [...r.strings('reasons'), if (inexact) 'amount_not_exact'],
    computedAt: r.dateTime('computed_at'),
  );
}

/// Reads the overview's figures (#2583). Every call is authorized there.
abstract interface class OverviewKpiRepository {
  /// The figure [kpiId] for the whole months [fromMonth, toMonth]: today's
  /// value, said as such for a past period.
  Future<OverviewFigure> figure(
    String workspaceId,
    String kpiId, {
    required String fromMonth,
    required String toMonth,
  });
}

/// No server in the demonstration: the figures say so.
class UnavailableOverviewKpiRepository implements OverviewKpiRepository {
  const UnavailableOverviewKpiRepository();

  @override
  Future<OverviewFigure> figure(
    String workspaceId,
    String kpiId, {
    required String fromMonth,
    required String toMonth,
  }) async => throw const KpiUnavailable('no server in this mode');
}
