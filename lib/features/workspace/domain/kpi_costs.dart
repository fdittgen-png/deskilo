// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C2 — the cost side of the figures, on the KPI contract (#1918):
// what the space spent on its day-to-day running, what it capitalised, its
// book depreciation, what its contracts still expect, how its shared costs
// spread over its resources, and what it expects to pay. The SERVER
// computes them (`kpi_costs_summary` 0529/0530/0532, `kpi_cost_allocation`
// 0531); this layer names them.
//
// Pure Dart: no Flutter, no l10n.
library;

import 'kpi_contract.dart';

const _operatingCostsKpi = KpiDefinition(
  id: 'purchases.operating_costs',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the document\'s date, whole months [from, to] on the workspace '
      'calendar: approved purchase lines classified operating, net plus the '
      'tax that cannot be recovered; a supplier credit note subtracts',
  dimensions: [],
  numerator: 'operating_costs_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['purchases', 'line classification', 'the workspace currency'],
  minCohort: null,
);

const _acquisitionsKpi = KpiDefinition(
  id: 'assets.acquisitions',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the document\'s date, whole months [from, to]: the equipment decided '
      'capitalise, at its cost; never a cost, never a depreciation',
  dimensions: [],
  numerator: 'acquisitions_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: [
    'purchases',
    'the equipment register',
    'the workspace currency',
  ],
  minCohort: null,
);

const _contributionKpi = KpiDefinition(
  id: 'finance.recorded_contribution',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the invoices\' months [from, to], net of their tax, less the operating '
      'costs of the same months: invoiced less recorded operating costs, '
      'never a profit',
  dimensions: [],
  numerator: 'contribution_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['invoicing', 'purchases', 'the workspace currency'],
  minCohort: null,
);

const _bookDepreciationKpi = KpiDefinition(
  id: 'assets.book_depreciation',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the confirmed book values (#2576) whose periods tile [from, to] '
      'exactly, complete and in the workspace currency; tax-only, partial or '
      'overlapping values are unknown, never 0',
  dimensions: [],
  numerator: 'book_depreciation_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: [
    'the equipment register',
    'confirmed book values',
    'the workspace currency',
  ],
  minCohort: null,
);

const _afterDepreciationKpi = KpiDefinition(
  id: 'finance.contribution_after_depreciation',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'invoiced less recorded operating costs of [from, to], less the book '
      'depreciation of the same months; unknown while that depreciation is',
  dimensions: [],
  numerator: 'after_depreciation_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: [
    'invoicing',
    'purchases',
    'confirmed book values',
    'the workspace currency',
  ],
  minCohort: null,
);

const _unbilledCommitmentsKpi = KpiDefinition(
  id: 'purchases.unbilled_commitments',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the contract occurrences due in [from, to] (#2575), those not yet '
      'generated projected from their schedule, less the bills matched to '
      'them; overdue and not yet due apart',
  dimensions: [],
  numerator: 'unbilled_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['a lease or a rented room', 'the workspace currency'],
  minCohort: null,
);

const _costAllocationKpi = KpiDefinition(
  id: 'finance.cost_allocation',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the operating costs of [from, to] by the document\'s date, spread over '
      'levels, offices, desks and seats by the rule revision in force that '
      'day; direct, shared and unallocated add up to the operating costs',
  dimensions: ['resource'],
  numerator: 'shared_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['purchases', 'an allocation rule', 'the workspace currency'],
  minCohort: null,
);

const _forecastOutflowsKpi = KpiDefinition(
  id: 'purchases.forecast_outflows',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'what is owed to suppliers at the end of [from, to] plus what the '
      'contracts still expect in those months; a bill matched to a contract '
      'counts once',
  dimensions: [],
  numerator: 'forecast_minor',
  denominator: '',
  aggregation: KpiAggregation.lastAtCutoff,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: [
    'purchases',
    'a lease or a rented room',
    'the workspace currency',
  ],
  minCohort: null,
);

/// The cost figures, in catalogue order (after the purchase ones).
const costKpis = <KpiDefinition>[
  _operatingCostsKpi,
  _acquisitionsKpi,
  _contributionKpi,
  _bookDepreciationKpi,
  _afterDepreciationKpi,
  _unbilledCommitmentsKpi,
  _costAllocationKpi,
  _forecastOutflowsKpi,
];
