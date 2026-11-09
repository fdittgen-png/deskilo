// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 5 -- the delivery figure of the vendor analytics: the purchase
// orders sent in the months, each in one cohort by whether its goods arrived
// by the expected date. The SERVER computes it (`kpi_vendor_quality`'s
// `delivery`, 0699) from the purchase orders and their goods receipts
// (#3307, 0681, 0684); this file names what it returns and reads it.
//
// Pure Dart: no Flutter, no l10n.
library;

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'kpi_contract.dart';

// #3294 step 5 -- the purchase orders sent in the months, by whether their
// goods reached the space by the expected date: purchase orders and goods
// receipts (#3307, 0681, 0684). The order is a document dated by the day it
// was SENT; a received order is on time when its last receipt is on or before
// the expected date.
const deliveryKpi = KpiDefinition(
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

/// What `delivery` of the vendor answer holds, typed.
typedef VendorDeliveryReading = ({
  int orders,
  Map<DeliveryCohort, int> cohorts,
  int? medianLead,
  int? p90Lead,
  int? medianDelay,
  int? p90Delay,
  List<VendorDelivery> rows,
});

/// Reads the `delivery` object; a server older than 0699 sends none: nothing
/// is invented (no orders, every cohort 0).
VendorDeliveryReading parseVendorDelivery(JsonReader? delivery) {
  int count(JsonReader r, String key) {
    final n = r.integer(key);
    if (n < 0) throw FormatException('Invalid count $key');
    return n;
  }

  final cohortRow = delivery?.objectOrNull('cohorts');
  return (
    orders: delivery == null ? 0 : count(delivery, 'orders'),
    cohorts: {
      for (final c in DeliveryCohort.values) c: cohortRow?.intOrNull(c.wire) ?? 0,
    },
    medianLead: delivery?.intOrNull('median_lead_days'),
    p90Lead: delivery?.intOrNull('p90_lead_days'),
    medianDelay: delivery?.intOrNull('median_delay_days'),
    p90Delay: delivery?.intOrNull('p90_delay_days'),
    rows: delivery == null
        ? const []
        : delivery.objects(
            'rows',
            (row) => (
              supplierId: row.string('supplier_id'),
              name: row.stringOr('name'),
              orders: count(row, 'orders'),
              onTime: count(row, 'on_time'),
              late: count(row, 'late'),
              medianLeadDays: row.intOrNull('median_lead_days'),
            ),
          ),
  );
}
