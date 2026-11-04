// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 2 — the vendor figures of a Demo space, computed over that
// space's own purchase documents and supplier payables by the server's
// rules (0673): a document costs its net plus the tax that cannot be
// recovered, a credit note subtracts; a payable is on time when its last
// payment was reported paid by its due date; a bill's lag runs from the
// supplier's date to the received date. Another currency in scope leaves
// every amount unknown, never summed.
import '../../../features/money/domain/purchase.dart';
import '../../../features/workspace/domain/kpi_contract.dart';
import '../../../features/workspace/domain/kpi_vendors.dart';
import '../../time/date_text.dart';
import 'purchase_repository.dart';

class DemoVendorKpiRepository implements VendorKpiRepository {
  DemoVendorKpiRepository({
    required this.purchases,
    required this.now,
    this.currency = 'EUR',
  });

  final FakePurchaseRepository purchases;
  final DateTime now;

  /// The space's currency: a US space does not read in euros.
  final String currency;

  /// The figure's definition (vendors.spend), as on the server.
  static const _top = 5;

  /// A technical bound on the listed rows, as on the server.
  static const _rows = 10;

  static String _month(DateTime d) => yearMonth(d.year, d.month);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The 0673 cost of one line: the net plus what cannot be recovered; the
  /// gross when the recoverable share is not known; the gross of an
  /// untaxed line.
  static int _cost(PurchaseLine l) => switch (l.netCents) {
    null => l.grossCents,
    final net => switch (l.recoverableTaxCents) {
      null => net + (l.taxCents ?? 0),
      final recoverable => net + (l.taxCents ?? 0) - recoverable,
    },
  };

  /// `percentile_disc`: the first value at or past the fraction.
  static int? _percentile(List<int> values, double fraction) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final index = (fraction * sorted.length).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  @override
  Future<VendorQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final c = _Scope(purchases, fromMonth, toMonth);
    final docs = c.documents();
    final due = c.due();
    final mixed =
        docs.any((d) => d.summary.currency != currency) ||
        purchases.payables.any(
          (p) =>
              p.obligation.creditorKind == CreditorKind.supplier &&
              p.obligation.currency != currency &&
              due.any((d) => d.supplier == p.obligation.creditorId),
        );
    int? money(int v) => mixed ? null : v;
    final partial = toMonth.compareTo(_month(now)) >= 0;
    final spend = _spend(c, docs, money);
    final lag = _lag(c, docs);
    final payment = _payment(c, due, money, mixed: mixed);
    return VendorQualityKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: currency,
      documents: spend.documents,
      creditNotes: spend.creditNotes,
      costMinor: spend.costMinor,
      creditedMinor: spend.creditedMinor,
      unassignedMinor: spend.unassignedMinor,
      topCount: _top,
      supplierCount: spend.vendors.length,
      topCostMinor: spend.topCostMinor,
      vendors: spend.vendors.take(_rows).toList(),
      months: spend.months,
      categoryCount: spend.categories.length,
      categories: spend.categories.take(_rows).toList(),
      cohorts: payment.cohorts,
      medianDays: payment.medianDays,
      p90Days: payment.p90Days,
      weightedDays: payment.weightedDays,
      punctuality: payment.punctuality,
      lagDocuments: lag.documents,
      lagUndated: lag.undated,
      lagDays: lag.days,
      lagMedianDays: lag.medianDays,
      lagP90Days: lag.p90Days,
      lags: lag.rows,
      quality: {
        if (mixed) KpiQuality.unavailable,
        if (partial) KpiQuality.partial,
      },
      reasons: [if (mixed) 'currency_mix', if (partial) 'period_not_over'],
      computedAt: now,
    );
  }

  /// [rows] summed by [keyOf] (a null key is left out), the largest cost
  /// first.
  static List<MapEntry<String, ({int cost, int documents})>> _grouped(
    List<_Doc> rows,
    String? Function(_Doc d) keyOf,
  ) {
    final by = <String, ({int cost, int documents})>{};
    for (final d in rows) {
      final k = keyOf(d);
      if (k == null) continue;
      final was = by[k] ?? (cost: 0, documents: 0);
      by[k] = (cost: was.cost + d.cost, documents: was.documents + 1);
    }
    return by.entries.toList()..sort((a, b) {
      final c = b.value.cost.compareTo(a.value.cost);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  }

  /// What the documents cost, by supplier, by category and by month.
  static ({
    int documents,
    int creditNotes,
    int? costMinor,
    int? creditedMinor,
    int? unassignedMinor,
    int? topCostMinor,
    List<VendorSpend> vendors,
    List<CategorySpend> categories,
    List<SpendMonth> months,
  })
  _spend(_Scope c, List<_Doc> docs, int? Function(int v) money) {
    bool credit(_Doc d) => d.summary.kind == PurchaseKind.creditNote;
    int sum(Iterable<_Doc> rows) => rows.fold<int>(0, (s, d) => s + d.cost);
    final ranked = _grouped(docs, (d) => d.supplier);
    final byMonth = <String, int>{};
    for (final d in docs) {
      final m = _month(d.summary.originalDate ?? d.summary.receivedOn!);
      byMonth[m] = (byMonth[m] ?? 0) + d.cost;
    }
    return (
      documents: docs.where((d) => !credit(d)).length,
      creditNotes: docs.where(credit).length,
      costMinor: money(sum(docs)),
      creditedMinor: money(-sum(docs.where(credit))),
      unassignedMinor: money(sum(docs.where((d) => d.supplier == null))),
      topCostMinor: money(
        ranked.take(_top).fold<int>(0, (s, e) => s + e.value.cost),
      ),
      vendors: [
        for (final (i, e) in ranked.indexed)
          VendorSpend(
            rank: i + 1,
            supplierId: e.key,
            name: c.nameOf(e.key),
            documents: e.value.documents,
            costMinor: money(e.value.cost),
          ),
      ],
      categories: [
        for (final e in _grouped(docs, (d) => d.summary.category.trim()))
          (
            category: e.key,
            documents: e.value.documents,
            costMinor: money(e.value.cost),
          ),
      ],
      months: [
        for (final m in byMonth.keys.toList()..sort())
          (month: m, costMinor: money(byMonth[m]!)),
      ],
    );
  }

  /// The payables by cohort, the delays, and how each supplier was paid.
  static ({
    Map<PayableCohort, PayableCohortFigure> cohorts,
    int? medianDays,
    int? p90Days,
    double? weightedDays,
    List<VendorPunctuality> punctuality,
  })
  _payment(
    _Scope c,
    List<_Due> due,
    int? Function(int v) money, {
    required bool mixed,
  }) {
    final settled = [
      for (final d in due)
        if (d.days != null) d,
    ];
    final weightBase = settled.fold<int>(0, (s, d) => s + d.total);
    final bySupplier = <String, List<_Due>>{};
    for (final d in due) {
      (bySupplier[d.supplier] ??= []).add(d);
    }
    int count(List<_Due> rows, PayableCohort k) =>
        rows.where((d) => d.cohort == k).length;
    return (
      cohorts: {
        for (final k in PayableCohort.values)
          k: (
            count: count(due, k),
            minor: money(
              due
                  .where((d) => d.cohort == k)
                  .fold<int>(0, (s, d) => s + d.total),
            ),
          ),
      },
      medianDays: _percentile([for (final d in settled) d.days!], 0.5),
      p90Days: _percentile([for (final d in settled) d.days!], 0.9),
      weightedDays: mixed || weightBase == 0
          ? null
          : (settled.fold<int>(0, (s, d) => s + d.days! * d.total) /
                        weightBase *
                        10)
                    .round() /
                10,
      punctuality:
          [
            for (final e in bySupplier.entries)
              (
                supplierId: e.key,
                name: c.nameOf(e.key),
                due: e.value.length,
                onTime: count(e.value, PayableCohort.onTime),
                late: count(e.value, PayableCohort.late),
                medianDays: _percentile([
                  for (final d in e.value) ?d.days,
                ], 0.5),
              ),
          ]..sort((a, b) {
            final k = b.due.compareTo(a.due);
            return k != 0 ? k : a.name.compareTo(b.name);
          }),
    );
  }

  /// How late the bills reached the space, and by supplier.
  static ({
    int documents,
    int undated,
    int days,
    int? medianDays,
    int? p90Days,
    List<VendorLag> rows,
  })
  _lag(_Scope c, List<_Doc> docs) {
    final bills = [
      for (final d in docs)
        if (d.summary.kind == PurchaseKind.bill) d,
    ];
    final lagged = [
      for (final d in bills)
        if (d.summary.originalDate case final from?)
          if (d.received case final to?)
            (
              supplier: d.supplier,
              days: _day(to).difference(_day(from)).inDays,
            ),
    ];
    final bySupplier = <String, List<int>>{};
    for (final l in lagged) {
      if (l.supplier case final s?) (bySupplier[s] ??= []).add(l.days);
    }
    return (
      documents: lagged.length,
      undated: bills.length - lagged.length,
      days: lagged.fold<int>(0, (s, l) => s + l.days),
      medianDays: _percentile([for (final l in lagged) l.days], 0.5),
      p90Days: _percentile([for (final l in lagged) l.days], 0.9),
      rows:
          [
            for (final e in bySupplier.entries)
              (
                supplierId: e.key,
                name: c.nameOf(e.key),
                documents: e.value.length,
                lagDays: e.value.fold<int>(0, (s, v) => s + v),
                medianDays: _percentile(e.value, 0.5),
              ),
          ]..sort((a, b) {
            final k = b.documents.compareTo(a.documents);
            return k != 0 ? k : a.name.compareTo(b.name);
          }),
    );
  }
}

/// One approved document of the months: its supplier and signed cost.
typedef _Doc = ({
  PurchaseSummary summary,
  String? supplier,
  int cost,
  DateTime? received,
});

/// One supplier payable falling due in the months, in its cohort.
typedef _Due = ({String supplier, int total, PayableCohort cohort, int? days});

/// The space's purchases as the months see them.
class _Scope {
  _Scope(this.purchases, this.fromMonth, this.toMonth)
    : payableOf = {
        for (final p in purchases.payables)
          if (p.obligation.creditorKind == CreditorKind.supplier)
            p.purchase.id: p.obligation,
      },
      byId = {for (final d in purchases.documents) d.summary.id: d};

  final FakePurchaseRepository purchases;
  final String fromMonth;
  final String toMonth;
  final Map<String, PurchaseObligation> payableOf;
  final Map<String, PurchaseDetail> byId;

  bool inRange(DateTime? d) {
    if (d == null) return false;
    final m = DemoVendorKpiRepository._month(d);
    return m.compareTo(fromMonth) >= 0 && m.compareTo(toMonth) <= 0;
  }

  String? supplierOf(PurchaseSummary s) =>
      s.supplierId ?? payableOf[s.id]?.creditorId;

  String nameOf(String id) {
    for (final d in purchases.documents) {
      if (supplierOf(d.summary) == id && d.supplierName != null) {
        return d.supplierName!;
      }
    }
    return payableOf.values
            .where((o) => o.creditorId == id)
            .firstOrNull
            ?.creditorName ??
        '';
  }

  /// The approved documents of the months, signed; a claim's receipt the
  /// Demo keeps only as a payable costs its gross.
  List<_Doc> documents() => [
    for (final d in purchases.documents)
      if (d.summary.state == PurchaseState.approved &&
          inRange(d.summary.originalDate ?? d.summary.receivedOn))
        (
          summary: d.summary,
          supplier: supplierOf(d.summary),
          cost:
              (d.summary.kind == PurchaseKind.creditNote ? -1 : 1) *
              d.lines.fold<int>(
                0,
                (s, l) => s + DemoVendorKpiRepository._cost(l),
              ),
          received: d.summary.receivedOn,
        ),
    for (final p in purchases.payables)
      if (!byId.containsKey(p.purchase.id) &&
          p.purchase.state == PurchaseState.approved &&
          inRange(p.purchase.originalDate ?? p.purchase.receivedOn))
        (
          summary: p.purchase,
          supplier: supplierOf(p.purchase),
          cost: p.purchase.grossCents,
          received: p.purchase.receivedOn,
        ),
  ];

  /// The supplier payables falling due in the months (or undated on a
  /// document of the months), each in one cohort.
  List<_Due> due() => [
    for (final p in purchases.payables)
      if (p.obligation.creditorKind == CreditorKind.supplier &&
          p.obligation.state != ObligationState.cancelled &&
          p.purchase.state == PurchaseState.approved)
        ?_dueOne(p),
  ];

  _Due? _dueOne(PayableRow p) {
    final o = p.obligation;
    final dueOn = o.dueOn ?? byId[p.purchase.id]?.dueOn;
    final dated = p.purchase.originalDate ?? p.purchase.receivedOn;
    if (dueOn == null ? !inRange(dated) : !inRange(dueOn)) return null;
    final settled = o.remainingCents <= 0;
    final payments = [
      for (final a in o.allocations)
        if (!a.isReversal && !a.reversed && !a.isOffset && !a.isCredit)
          ?a.paidOn,
    ]..sort();
    final paid = payments.isEmpty
        ? null
        : DemoVendorKpiRepository._day(payments.last);
    final day = dueOn == null ? null : DemoVendorKpiRepository._day(dueOn);
    return (
      supplier: o.creditorId,
      total: o.amountCents,
      cohort: _cohortOf(o, day, paid, settled: settled),
      days: settled && paid != null && day != null
          ? paid.difference(day).inDays
          : null,
    );
  }

  static PayableCohort _cohortOf(
    PurchaseObligation o,
    DateTime? due,
    DateTime? paid, {
    required bool settled,
  }) {
    if (due == null) return PayableCohort.unknownDue;
    if (settled) {
      if (paid == null) return PayableCohort.undated;
      return paid.isAfter(due) ? PayableCohort.late : PayableCohort.onTime;
    }
    if (o.state == ObligationState.held) return PayableCohort.held;
    return o.remainingCents < o.amountCents
        ? PayableCohort.partial
        : PayableCohort.open;
  }
}
