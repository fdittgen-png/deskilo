// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 — the customer side of the figures, on the KPI contract (#1918):
// how customers pay against their due dates, how much dunning that takes,
// what was credited or written off, and how concentrated the sales are.
// The SERVER computes them (`kpi_customer_quality`, 0671) from the
// invoices, their maturities, matches, reminders and holds; this layer
// names what it returns.
//
//   * a payment is dated by the day it was reported paid (the bank's value
//     date when a reconciled line explains it, the ledger's date otherwise),
//     never by the day it was matched;
//   * amounts are minor units of the workspace currency; another currency
//     in scope leaves them unknown (`currency_mix`), never summed;
//   * sales amounts are net of VAT;
//   * the customers' names travel only to a reader holding
//     `viewPersonalData`; everyone else reads ranks.
//
// Pure Dart: no Flutter, no l10n.
library;

import '../../../core/data/json_reader.dart';
import 'kpi_contract.dart';

const _paymentBehaviourKpi = KpiDefinition(
  id: 'customers.payment_behaviour',
  version: 1,
  unit: 'percent',
  timeBasis:
      'the invoices falling due in whole months [from, to] on the workspace '
      'calendar: the share of the settled ones paid by their due date, the '
      'payment dated by the day it was reported paid',
  dateBasis: KpiDateBasis.invoiceDue,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'on_time_count',
  denominator: 'completed_count',
  aggregation: KpiAggregation.ratioOfSums,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: [
    'invoicing',
    'due dates',
    'recorded payments',
    'the workspace currency',
  ],
  minCohort: null,
);

const _dunningLoadKpi = KpiDefinition(
  id: 'customers.dunning_load',
  version: 1,
  unit: 'count',
  timeBasis:
      'the reminders sent for the invoices falling due in whole months '
      '[from, to] on the workspace calendar',
  dateBasis: KpiDateBasis.invoiceDue,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'reminders',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['invoicing', 'dunning', 'due dates'],
  minCohort: null,
);

const _creditAndWriteoffKpi = KpiDefinition(
  id: 'customers.credit_and_writeoff',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the invoice\'s month, whole months [from, to]: the credit notes net '
      'of VAT, and the written-off remainders in proportion to their '
      'invoice\'s net',
  dateBasis: KpiDateBasis.invoiceMonth,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'credited_and_written_off_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['invoicing', 'payment matching', 'the workspace currency'],
  minCohort: null,
);

const _concentrationKpi = KpiDefinition(
  id: 'customers.concentration',
  version: 1,
  unit: 'percent',
  timeBasis:
      'the invoice\'s month, whole months [from, to]: the share of the net '
      'invoiced that the largest customers make',
  dateBasis: KpiDateBasis.invoiceMonth,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'top_net_minor',
  denominator: 'net_minor',
  aggregation: KpiAggregation.ratioOfSums,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['invoicing', 'the workspace currency'],
  minCohort: null,
);

/// The customer figures, in catalogue order.
const customerKpis = <KpiDefinition>[
  _paymentBehaviourKpi,
  _dunningLoadKpi,
  _creditAndWriteoffKpi,
  _concentrationKpi,
];

/// The cohorts an invoice falling due lands in, in display order. Each
/// invoice is in exactly one.
enum PaymentCohort {
  onTime('on_time'),
  late('late'),

  /// Settled without a reported payment date (a credit note, a match
  /// without a recorded payment): neither on time nor late.
  undated('undated'),

  /// Part of it paid and accepted; the rest neither paid nor written off.
  partial('partial'),
  open('open'),

  /// Unpaid, under an active dunning hold.
  held('held'),
  writtenOff('written_off'),

  /// No due date was frozen: it cannot be on time or late.
  unknownDue('unknown_due');

  const PaymentCohort(this.wire);
  final String wire;
}

/// One cohort: how many invoices, and their amount (gross: a receivable
/// is owed with its VAT). A null amount is unknown, never 0.
typedef CohortFigure = ({int count, int? minor});

/// One customer of the concentration, by rank. [name] is null unless the
/// reader may read personal data: the server leaves it out.
class CustomerShare {
  const CustomerShare({
    required this.rank,
    required this.name,
    required this.netMinor,
    required this.openMinor,
  });

  final int rank;
  final String? name;
  final int? netMinor;
  final int? openMinor;
}

/// One invoice month of the credits and write-offs.
typedef CreditMonth = ({String month, int? creditedMinor, int? writtenOffMinor});

/// What `kpi_customer_quality` returned for the whole months
/// [fromMonth, toMonth], typed. A missing amount is null, never 0.
class CustomerQualityKpi {
  const CustomerQualityKpi({
    required this.fromMonth,
    required this.toMonth,
    required this.currency,
    required this.namesVisible,
    required this.cohorts,
    required this.medianDays,
    required this.p90Days,
    required this.weightedDays,
    required this.dunning,
    required this.creditNotes,
    required this.creditedMinor,
    required this.writeOffs,
    required this.writtenOffMinor,
    required this.creditMonths,
    required this.topCount,
    required this.customerCount,
    required this.netMinor,
    required this.topNetMinor,
    required this.openMinor,
    required this.topOpenMinor,
    required this.customers,
    required this.quality,
    required this.reasons,
    required this.computedAt,
  });

  final String fromMonth;
  final String toMonth;
  final String currency;

  /// Whether [customers] carry names (the reader holds `viewPersonalData`).
  final bool namesVisible;

  final Map<PaymentCohort, CohortFigure> cohorts;

  /// Days from the due date to the reported payment over the settled
  /// invoices (negative = early); null without any.
  final int? medianDays;
  final int? p90Days;

  /// The same delay weighted by the invoices' amounts.
  final double? weightedDays;

  /// Null while dunning is switched off for the workspace.
  final DunningLoad? dunning;

  final int creditNotes;
  final int? creditedMinor;
  final int writeOffs;
  final int? writtenOffMinor;
  final List<CreditMonth> creditMonths;

  /// How many of the largest customers the share counts.
  final int topCount;
  final int customerCount;
  final int? netMinor;
  final int? topNetMinor;

  /// What the customers owe now, and the part the same largest owe.
  final int? openMinor;
  final int? topOpenMinor;

  /// The largest customers by net invoiced, the largest first.
  final List<CustomerShare> customers;

  final Set<KpiQuality> quality;
  final List<String> reasons;
  final DateTime computedAt;

  int get onTimeCount => cohorts[PaymentCohort.onTime]?.count ?? 0;

  /// The settled invoices with a reported payment date.
  int get completedCount =>
      onTimeCount + (cohorts[PaymentCohort.late]?.count ?? 0);

  int? get creditedAndWrittenOffMinor =>
      creditedMinor == null || writtenOffMinor == null
      ? null
      : creditedMinor! + writtenOffMinor!;
}

/// The reminders of the invoices falling due in the months.
class DunningLoad {
  const DunningLoad({
    required this.dueInvoices,
    required this.remindedInvoices,
    required this.reminders,
    required this.byLevel,
    required this.paidAfterReminder,
  });

  final int dueInvoices;
  final int remindedInvoices;
  final int reminders;

  /// Reminders by their level (1 = the first).
  final Map<int, int> byLevel;

  /// Reminded invoices that were paid after their first reminder: a
  /// sequence in time, not proof the reminder caused the payment.
  final int paidAfterReminder;
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
CustomerQualityKpi customerQualityFromJson(Map<String, Object?> json) {
  final r = JsonReader(json, context: 'kpi_customer_quality');
  var inexact = false;
  // A null amount is unknown on purpose (another currency in scope); only
  // a present value that cannot travel exactly is inexact.
  int? minor(JsonReader row, String key) {
    final raw = row.raw(key);
    final v = exactMinor(raw);
    if (raw != null && v == null) inexact = true;
    return v;
  }

  final payment = _object(r, 'payment');
  final cohortRows = _object(payment, 'cohorts');
  final cohorts = {
    for (final c in PaymentCohort.values)
      if (cohortRows.objectOrNull(c.wire) case final row?)
        c: (count: _count(row, 'count'), minor: minor(row, 'minor')),
  };
  final dunningRow = r.objectOrNull('dunning');
  final credit = _object(r, 'credit');
  final top = _object(r, 'concentration');
  final customers = top.objects(
    'rows',
    (row) => CustomerShare(
      rank: _count(row, 'rank'),
      name: row.stringOrNull('name'),
      netMinor: minor(row, 'net_minor'),
      openMinor: minor(row, 'open_minor'),
    ),
  );
  final creditMonths = credit.objects(
    'months',
    (row) => (
      month: row.string('month'),
      creditedMinor: minor(row, 'credited_minor'),
      writtenOffMinor: minor(row, 'written_off_minor'),
    ),
  );
  final creditedMinor = minor(credit, 'credited_minor');
  final writtenOffMinor = minor(credit, 'written_off_minor');
  final netMinor = minor(top, 'net_minor');
  final topNetMinor = minor(top, 'top_net_minor');
  final openMinor = minor(top, 'open_minor');
  final topOpenMinor = minor(top, 'top_open_minor');
  final currency = r.stringOr('currency');
  return CustomerQualityKpi(
    fromMonth: r.stringOr('from'),
    toMonth: r.stringOr('to'),
    currency: currency,
    namesVisible: r.isTrue('names_visible'),
    cohorts: cohorts,
    medianDays: payment.intOrNull('median_days'),
    p90Days: payment.intOrNull('p90_days'),
    weightedDays: payment.doubleOrNull('weighted_days'),
    dunning: dunningRow == null
        ? null
        : DunningLoad(
            dueInvoices: _count(dunningRow, 'due_invoices'),
            remindedInvoices: _count(dunningRow, 'reminded_invoices'),
            reminders: _count(dunningRow, 'reminders'),
            byLevel: {
              for (final e in dunningRow.objectOrEmpty('by_level').entries)
                int.parse(e.key): (e.value! as num).toInt(),
            },
            paidAfterReminder: _count(dunningRow, 'paid_after_reminder'),
          ),
    creditNotes: _count(credit, 'credit_notes'),
    creditedMinor: creditedMinor,
    writeOffs: _count(credit, 'write_offs'),
    writtenOffMinor: writtenOffMinor,
    creditMonths: creditMonths,
    topCount: _count(top, 'top_count'),
    customerCount: _count(top, 'customers'),
    netMinor: netMinor,
    topNetMinor: topNetMinor,
    openMinor: openMinor,
    topOpenMinor: topOpenMinor,
    customers: customers,
    quality: {
      for (final q in r.strings('quality'))
        kpiQualityOf(q) ?? KpiQuality.unavailable,
      if (inexact || currency.isEmpty) KpiQuality.unavailable,
    },
    reasons: [...r.strings('reasons'), if (inexact) 'amount_not_exact'],
    computedAt: r.dateTime('computed_at'),
  );
}

/// Reads the customer figures (#3294). Every call is authorized there.
abstract interface class CustomerKpiRepository {
  /// The figures of the whole months [fromMonth, toMonth] (`YYYY-MM`).
  Future<CustomerQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  });
}
