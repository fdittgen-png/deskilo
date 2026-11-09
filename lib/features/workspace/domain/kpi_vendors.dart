// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 2 — the purchase and vendor side of the figures, on the KPI
// contract (#1918): what the space buys and from whom, how punctually it
// pays its suppliers, and how late their bills reach it. The SERVER computes
// them (`kpi_vendor_quality`, 0673) from the approved purchase documents,
// their lines, the supplier payables and the payments recorded against
// them; this layer names what it returns.
//
//   * a document costs its net plus the tax that cannot be recovered; a
//     credit note subtracts;
//   * a payment is dated by the day it was reported paid (the bank's value
//     date when the payment carries one);
//   * amounts are minor units of the workspace currency; another currency
//     in scope leaves them unknown (`currency_mix`), never summed.
//
// Delivery time needs purchase orders and receipts, unit prices and margins
// need items on purchase lines: later steps of #3294.
//
// Pure Dart: no Flutter, no l10n.
library;

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'kpi_contract.dart';

const _spendKpi = KpiDefinition(
  id: 'vendors.spend',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the approved purchase documents dated in whole months [from, to] on '
      'the workspace calendar: their net plus the tax that cannot be '
      'recovered, a credit note subtracted, by supplier',
  dateBasis: KpiDateBasis.documentDate,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'cost_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['purchases', 'approved documents', 'the workspace currency'],
  minCohort: null,
);

const _categorySpendKpi = KpiDefinition(
  id: 'vendors.category_spend',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the approved purchase documents dated in whole months [from, to] on '
      'the workspace calendar, by the document\'s category',
  dateBasis: KpiDateBasis.documentDate,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'cost_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['purchases', 'approved documents', 'the workspace currency'],
  minCohort: null,
);

const _paymentPunctualityKpi = KpiDefinition(
  id: 'vendors.payment_punctuality',
  version: 1,
  unit: 'percent',
  timeBasis:
      'the supplier payables falling due in whole months [from, to] on the '
      'workspace calendar: the share of the settled ones paid by their due '
      'date, the payment dated by the day it was reported paid',
  dateBasis: KpiDateBasis.payableDue,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'on_time_count',
  denominator: 'completed_count',
  aggregation: KpiAggregation.ratioOfSums,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['purchases', 'due dates', 'recorded supplier payments'],
  minCohort: null,
);

const _billingLagKpi = KpiDefinition(
  id: 'vendors.billing_lag',
  version: 1,
  unit: 'days',
  timeBasis:
      'the approved supplier bills dated in whole months [from, to] on the '
      'workspace calendar that carry both dates: the days from the date the '
      'supplier put on the bill to the day it reached the space',
  dateBasis: KpiDateBasis.documentDate,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'lag_days',
  denominator: 'documents',
  aggregation: KpiAggregation.ratioOfSums,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['purchases', 'the supplier\'s date', 'the received date'],
  minCohort: null,
);

// #3294 step 5 -- the purchase orders sent in the months, by whether their
// goods reached the space by the expected date: purchase orders and goods
// receipts (#3307, 0681, 0684). The order is a document dated by the day it
// was SENT; a received order is on time when its last receipt is on or before
// the expected date.
const _deliveryKpi = KpiDefinition(
  id: 'vendors.delivery',
  version: 1,
  unit: 'percent',
  timeBasis:
      'the purchase orders sent in whole months [from, to] on the workspace '
      'calendar: the share of the received ones whose last goods receipt is '
      'on or before the expected date',
  dateBasis: KpiDateBasis.documentDate,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'on_time_count',
  denominator: 'completed_count',
  aggregation: KpiAggregation.ratioOfSums,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['purchase orders', 'the expected date', 'goods receipts'],
  minCohort: null,
);

/// The vendor figures, in catalogue order.
const vendorKpis = <KpiDefinition>[
  _spendKpi,
  _categorySpendKpi,
  _paymentPunctualityKpi,
  _billingLagKpi,
  _deliveryKpi,
];

/// The cohorts a purchase order sent in the months lands in, in display
/// order. Each order is in exactly one.
enum DeliveryCohort {
  onTime('on_time'),
  late('late'),

  /// Received, but the order named no expected date: neither on time nor
  /// late.
  unknownExpected('unknown_expected'),

  /// Part of it received; the rest still awaited.
  partial('partial'),

  /// Nothing received, and the expected date has passed.
  overdue('overdue'),

  /// Nothing received yet, and it is not overdue.
  open('open');

  const DeliveryCohort(this.wire);
  final String wire;
}

/// How reliably one supplier delivered.
typedef VendorDelivery = ({
  String supplierId,
  String name,
  int orders,
  int onTime,
  int late,
  int? medianLeadDays,
});

/// The cohorts a supplier payable falling due lands in, in display order.
/// Each payable is in exactly one.
enum PayableCohort {
  onTime('on_time'),
  late('late'),

  /// Settled without a reported payment (a credit, an offset): neither on
  /// time nor late.
  undated('undated'),

  /// Part of it paid; the rest still owed.
  partial('partial'),
  open('open'),

  /// Unpaid, put on hold.
  held('held'),

  /// No due date on the payable: it cannot be on time or late.
  unknownDue('unknown_due');

  const PayableCohort(this.wire);
  final String wire;
}

/// One cohort: how many payables, and their amount. A null amount is
/// unknown, never 0.
typedef PayableCohortFigure = ({int count, int? minor});

/// One supplier's cost in the months, by rank (the largest first).
class VendorSpend {
  const VendorSpend({
    required this.rank,
    required this.supplierId,
    required this.name,
    required this.documents,
    required this.costMinor,
  });

  final int rank;
  final String supplierId;
  final String name;
  final int documents;
  final int? costMinor;
}

/// One category's cost in the months.
typedef CategorySpend = ({String category, int documents, int? costMinor});

/// One month's cost.
typedef SpendMonth = ({String month, int? costMinor});

/// How punctually one supplier was paid.
typedef VendorPunctuality = ({
  String supplierId,
  String name,
  int due,
  int onTime,
  int late,
  int? medianDays,
});

/// How late one supplier's bills reached the space.
typedef VendorLag = ({
  String supplierId,
  String name,
  int documents,
  int lagDays,
  int? medianDays,
});

/// What `kpi_vendor_quality` returned for the whole months
/// [fromMonth, toMonth], typed. A missing amount is null, never 0.
class VendorQualityKpi {
  const VendorQualityKpi({
    required this.fromMonth,
    required this.toMonth,
    required this.currency,
    required this.documents,
    required this.creditNotes,
    required this.costMinor,
    required this.creditedMinor,
    required this.unassignedMinor,
    required this.topCount,
    required this.supplierCount,
    required this.topCostMinor,
    required this.vendors,
    required this.months,
    required this.categoryCount,
    required this.categories,
    required this.cohorts,
    required this.medianDays,
    required this.p90Days,
    required this.weightedDays,
    required this.punctuality,
    required this.lagDocuments,
    required this.lagUndated,
    required this.lagDays,
    required this.lagMedianDays,
    required this.lagP90Days,
    required this.lags,
    required this.quality,
    required this.reasons,
    required this.computedAt,
    this.deliveryOrders = 0,
    this.deliveryCohorts = const {},
    this.deliveryMedianLeadDays,
    this.deliveryP90LeadDays,
    this.deliveryMedianDelayDays,
    this.deliveryP90DelayDays,
    this.deliveries = const [],
  });

  final String fromMonth;
  final String toMonth;
  final String currency;

  /// The bills and receipts of the months, and the credit notes apart.
  final int documents;
  final int creditNotes;

  /// What they cost, the credit notes subtracted.
  final int? costMinor;
  final int? creditedMinor;

  /// The cost of documents filed under no supplier (a member's receipt).
  final int? unassignedMinor;

  /// How many of the largest suppliers [topCostMinor] counts.
  final int topCount;
  final int supplierCount;
  final int? topCostMinor;

  /// The largest suppliers by cost, the largest first.
  final List<VendorSpend> vendors;
  final List<SpendMonth> months;

  final int categoryCount;

  /// The largest categories by cost, the largest first.
  final List<CategorySpend> categories;

  final Map<PayableCohort, PayableCohortFigure> cohorts;

  /// Days from the due date to the reported payment over the settled
  /// payables (negative = early); null without any.
  final int? medianDays;
  final int? p90Days;

  /// The same delay weighted by the payables' amounts.
  final double? weightedDays;

  /// Per supplier, the one with most payables due first.
  final List<VendorPunctuality> punctuality;

  /// The bills that carry both dates, and the ones missing one.
  final int lagDocuments;
  final int lagUndated;

  /// The days from the supplier's date to the received date, summed.
  final int lagDays;
  final int? lagMedianDays;
  final int? lagP90Days;

  /// Per supplier, the one with most bills first.
  final List<VendorLag> lags;

  final Set<KpiQuality> quality;
  final List<String> reasons;
  final DateTime computedAt;

  /// The purchase orders sent in the months (#3294 step 5), each in one
  /// cohort; none from a server older than 0699.
  final int deliveryOrders;
  final Map<DeliveryCohort, int> deliveryCohorts;

  /// Days from the day an order was sent to its last receipt, and from the
  /// expected date to it (negative = early), over the received orders.
  final int? deliveryMedianLeadDays;
  final int? deliveryP90LeadDays;
  final int? deliveryMedianDelayDays;
  final int? deliveryP90DelayDays;

  /// Per supplier, the one with most orders first.
  final List<VendorDelivery> deliveries;

  int get deliveryOnTimeCount => deliveryCohorts[DeliveryCohort.onTime] ?? 0;

  /// The received orders that named an expected date.
  int get deliveryCompletedCount =>
      deliveryOnTimeCount + (deliveryCohorts[DeliveryCohort.late] ?? 0);

  int get onTimeCount => cohorts[PayableCohort.onTime]?.count ?? 0;

  /// The settled payables with a reported payment date.
  int get completedCount =>
      onTimeCount + (cohorts[PayableCohort.late]?.count ?? 0);
}

JsonReader _object(JsonReader r, String key) =>
    r.objectOrNull(key) ?? (throw FormatException('Missing $key'));

int _count(JsonReader r, String key) {
  final n = r.integer(key);
  if (n < 0) throw FormatException('Invalid count $key');
  return n;
}

/// Parses the RPC's jsonb. An amount that cannot travel exactly makes the
/// amounts unavailable (`amount_not_exact`), never a rounded number.
VendorQualityKpi vendorQualityFromJson(Map<String, Object?> json) {
  final r = JsonReader(json, context: 'kpi_vendor_quality');
  var inexact = false;
  // A null amount is unknown on purpose (another currency in scope); only
  // a present value that cannot travel exactly is inexact.
  int? minor(JsonReader row, String key) {
    final raw = row.raw(key);
    final v = exactMinor(raw);
    if (raw != null && v == null) inexact = true;
    return v;
  }

  final spend = _object(r, 'spend');
  final vendors = spend.objects(
    'rows',
    (row) => VendorSpend(
      rank: _count(row, 'rank'),
      supplierId: row.string('supplier_id'),
      name: row.stringOr('name'),
      documents: _count(row, 'documents'),
      costMinor: minor(row, 'cost_minor'),
    ),
  );
  final months = spend.objects(
    'months',
    (row) => (month: row.string('month'), costMinor: minor(row, 'cost_minor')),
  );
  final categoryRow = _object(r, 'categories');
  final categories = categoryRow.objects(
    'rows',
    (row) => (
      category: row.stringOr('category'),
      documents: _count(row, 'documents'),
      costMinor: minor(row, 'cost_minor'),
    ),
  );
  final payment = _object(r, 'payment');
  final cohortRows = _object(payment, 'cohorts');
  final cohorts = {
    for (final c in PayableCohort.values)
      if (cohortRows.objectOrNull(c.wire) case final row?)
        c: (count: _count(row, 'count'), minor: minor(row, 'minor')),
  };
  final punctuality = payment.objects(
    'rows',
    (row) => (
      supplierId: row.string('supplier_id'),
      name: row.stringOr('name'),
      due: _count(row, 'due'),
      onTime: _count(row, 'on_time'),
      late: _count(row, 'late'),
      medianDays: row.intOrNull('median_days'),
    ),
  );
  final lag = _object(r, 'billing_lag');
  final lags = lag.objects(
    'rows',
    (row) => (
      supplierId: row.string('supplier_id'),
      name: row.stringOr('name'),
      documents: _count(row, 'documents'),
      lagDays: row.integer('lag_days'),
      medianDays: row.intOrNull('median_days'),
    ),
  );
  final delivery = r.objectOrNull('delivery');
  final deliveryCohortRow = delivery?.objectOrNull('cohorts');
  final deliveries = delivery == null
      ? const <VendorDelivery>[]
      : delivery.objects(
          'rows',
          (row) => (
            supplierId: row.string('supplier_id'),
            name: row.stringOr('name'),
            orders: _count(row, 'orders'),
            onTime: _count(row, 'on_time'),
            late: _count(row, 'late'),
            medianLeadDays: row.intOrNull('median_lead_days'),
          ),
        );
  final costMinor = minor(spend, 'cost_minor');
  final creditedMinor = minor(spend, 'credited_minor');
  final unassignedMinor = minor(spend, 'unassigned_minor');
  final topCostMinor = minor(spend, 'top_cost_minor');
  final currency = r.stringOr('currency');
  return VendorQualityKpi(
    fromMonth: r.stringOr('from'),
    toMonth: r.stringOr('to'),
    currency: currency,
    documents: _count(spend, 'documents'),
    creditNotes: _count(spend, 'credit_notes'),
    costMinor: costMinor,
    creditedMinor: creditedMinor,
    unassignedMinor: unassignedMinor,
    topCount: _count(spend, 'top_count'),
    supplierCount: _count(spend, 'suppliers'),
    topCostMinor: topCostMinor,
    vendors: vendors,
    months: months,
    categoryCount: _count(categoryRow, 'categories'),
    categories: categories,
    cohorts: cohorts,
    medianDays: payment.intOrNull('median_days'),
    p90Days: payment.intOrNull('p90_days'),
    weightedDays: payment.doubleOrNull('weighted_days'),
    punctuality: punctuality,
    lagDocuments: _count(lag, 'documents'),
    lagUndated: _count(lag, 'undated'),
    lagDays: lag.integer('lag_days'),
    lagMedianDays: lag.intOrNull('median_days'),
    lagP90Days: lag.intOrNull('p90_days'),
    lags: lags,
    quality: {
      for (final q in r.strings('quality'))
        kpiQualityOf(q) ?? KpiQuality.unavailable,
      if (inexact || currency.isEmpty) KpiQuality.unavailable,
    },
    reasons: [...r.strings('reasons'), if (inexact) 'amount_not_exact'],
    computedAt: r.dateTime('computed_at'),
    deliveryOrders: delivery == null ? 0 : _count(delivery, 'orders'),
    deliveryCohorts: {
      for (final c in DeliveryCohort.values)
        c: deliveryCohortRow?.intOrNull(c.wire) ?? 0,
    },
    deliveryMedianLeadDays: delivery?.intOrNull('median_lead_days'),
    deliveryP90LeadDays: delivery?.intOrNull('p90_lead_days'),
    deliveryMedianDelayDays: delivery?.intOrNull('median_delay_days'),
    deliveryP90DelayDays: delivery?.intOrNull('p90_delay_days'),
    deliveries: deliveries,
  );
}

/// Reads the vendor figures (#3294 step 2). Every call is authorized there.
abstract interface class VendorKpiRepository {
  /// The figures of the whole months [fromMonth, toMonth] (`YYYY-MM`).
  Future<VendorQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  });
}
