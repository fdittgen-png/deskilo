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
    bool inRange(DateTime? d) {
      if (d == null) return false;
      final m = _month(d);
      return m.compareTo(fromMonth) >= 0 && m.compareTo(toMonth) <= 0;
    }

    final payableOf = {
      for (final p in purchases.payables)
        if (p.obligation.creditorKind == CreditorKind.supplier)
          p.purchase.id: p.obligation,
    };
    final documents = {for (final d in purchases.documents) d.summary.id: d};
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

    // The approved documents of the months, signed; a claim's receipt the
    // Demo keeps only as a payable costs its gross.
    final docs =
        <
          ({
            PurchaseSummary summary,
            String? supplier,
            int cost,
            DateTime? received,
          })
        >[
          for (final d in purchases.documents)
            if (d.summary.state == PurchaseState.approved &&
                inRange(d.summary.originalDate ?? d.summary.receivedOn))
              (
                summary: d.summary,
                supplier: supplierOf(d.summary),
                cost:
                    (d.summary.kind == PurchaseKind.creditNote ? -1 : 1) *
                    d.lines.fold<int>(0, (s, l) => s + _cost(l)),
                received: d.summary.receivedOn,
              ),
          for (final p in purchases.payables)
            if (!documents.containsKey(p.purchase.id) &&
                p.purchase.state == PurchaseState.approved &&
                inRange(p.purchase.originalDate ?? p.purchase.receivedOn))
              (
                summary: p.purchase,
                supplier: supplierOf(p.purchase),
                cost: p.purchase.grossCents,
                received: p.purchase.receivedOn,
              ),
        ];

    // The supplier payables falling due in the months (or undated on a
    // document of the months), each in one cohort.
    final due =
        <({String supplier, int total, PayableCohort cohort, int? days})>[];
    for (final p in purchases.payables) {
      final o = p.obligation;
      if (o.creditorKind != CreditorKind.supplier ||
          o.state == ObligationState.cancelled ||
          p.purchase.state != PurchaseState.approved) {
        continue;
      }
      final dueOn = o.dueOn ?? documents[p.purchase.id]?.dueOn;
      final dated = p.purchase.originalDate ?? p.purchase.receivedOn;
      if (dueOn == null ? !inRange(dated) : !inRange(dueOn)) continue;
      final settled = o.remainingCents <= 0;
      final payments = [
        for (final a in o.allocations)
          if (!a.isReversal && !a.reversed && !a.isOffset && !a.isCredit)
            ?a.paidOn,
      ]..sort();
      final paid = payments.isEmpty ? null : _day(payments.last);
      final cohort = dueOn == null
          ? PayableCohort.unknownDue
          : settled && paid == null
          ? PayableCohort.undated
          : settled && !paid!.isAfter(_day(dueOn))
          ? PayableCohort.onTime
          : settled
          ? PayableCohort.late
          : o.state == ObligationState.held
          ? PayableCohort.held
          : o.remainingCents < o.amountCents
          ? PayableCohort.partial
          : PayableCohort.open;
      due.add((
        supplier: o.creditorId,
        total: o.amountCents,
        cohort: cohort,
        days: settled && paid != null && dueOn != null
            ? paid.difference(_day(dueOn)).inDays
            : null,
      ));
    }

    final mixed =
        docs.any((d) => d.summary.currency != currency) ||
        purchases.payables.any(
          (p) =>
              p.obligation.creditorKind == CreditorKind.supplier &&
              p.obligation.currency != currency &&
              due.any((d) => d.supplier == p.obligation.creditorId),
        );
    int? money(int v) => mixed ? null : v;

    // The cost by supplier, the largest first.
    final bySupplier = <String, ({int cost, int documents})>{};
    for (final d in docs) {
      final s = d.supplier;
      if (s == null) continue;
      final was = bySupplier[s] ?? (cost: 0, documents: 0);
      bySupplier[s] = (cost: was.cost + d.cost, documents: was.documents + 1);
    }
    final ranked = bySupplier.entries.toList()
      ..sort((a, b) {
        final c = b.value.cost.compareTo(a.value.cost);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    final vendors = [
      for (final (i, e) in ranked.indexed)
        VendorSpend(
          rank: i + 1,
          supplierId: e.key,
          name: nameOf(e.key),
          documents: e.value.documents,
          costMinor: money(e.value.cost),
        ),
    ];

    final byCategory = <String, ({int cost, int documents})>{};
    for (final d in docs) {
      final c = d.summary.category.trim();
      final was = byCategory[c] ?? (cost: 0, documents: 0);
      byCategory[c] = (cost: was.cost + d.cost, documents: was.documents + 1);
    }
    final categories = byCategory.entries.toList()
      ..sort((a, b) {
        final c = b.value.cost.compareTo(a.value.cost);
        return c != 0 ? c : a.key.compareTo(b.key);
      });

    final byMonth = <String, int>{};
    for (final d in docs) {
      final m = _month(d.summary.originalDate ?? d.summary.receivedOn!);
      byMonth[m] = (byMonth[m] ?? 0) + d.cost;
    }

    final settled = [
      for (final d in due)
        if (d.days != null) d,
    ];
    final weightBase = settled.fold<int>(0, (s, d) => s + d.total);
    final bySupplierDue =
        <String, List<({int total, PayableCohort cohort, int? days})>>{};
    for (final d in due) {
      (bySupplierDue[d.supplier] ??= []).add((
        total: d.total,
        cohort: d.cohort,
        days: d.days,
      ));
    }
    final punctuality =
        [
          for (final e in bySupplierDue.entries)
            (
              supplierId: e.key,
              name: nameOf(e.key),
              due: e.value.length,
              onTime: e.value
                  .where((d) => d.cohort == PayableCohort.onTime)
                  .length,
              late: e.value.where((d) => d.cohort == PayableCohort.late).length,
              medianDays: _percentile([for (final d in e.value) ?d.days], 0.5),
            ),
        ]..sort((a, b) {
          final c = b.due.compareTo(a.due);
          return c != 0 ? c : a.name.compareTo(b.name);
        });

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
    final bySupplierLag = <String, List<int>>{};
    for (final l in lagged) {
      if (l.supplier case final s?) (bySupplierLag[s] ??= []).add(l.days);
    }
    final lags =
        [
          for (final e in bySupplierLag.entries)
            (
              supplierId: e.key,
              name: nameOf(e.key),
              documents: e.value.length,
              lagDays: e.value.fold<int>(0, (s, v) => s + v),
              medianDays: _percentile(e.value, 0.5),
            ),
        ]..sort((a, b) {
          final c = b.documents.compareTo(a.documents);
          return c != 0 ? c : a.name.compareTo(b.name);
        });

    final partial = toMonth.compareTo(_month(now)) >= 0;
    final totalCost = docs.fold<int>(0, (s, d) => s + d.cost);
    final credited = -docs
        .where((d) => d.summary.kind == PurchaseKind.creditNote)
        .fold<int>(0, (s, d) => s + d.cost);
    return VendorQualityKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: currency,
      documents: docs
          .where((d) => d.summary.kind != PurchaseKind.creditNote)
          .length,
      creditNotes: docs
          .where((d) => d.summary.kind == PurchaseKind.creditNote)
          .length,
      costMinor: money(totalCost),
      creditedMinor: money(credited),
      unassignedMinor: money(
        docs
            .where((d) => d.supplier == null)
            .fold<int>(0, (s, d) => s + d.cost),
      ),
      topCount: _top,
      supplierCount: vendors.length,
      topCostMinor: money(
        vendors
            .take(_top)
            .fold<int>(0, (s, v) => s + bySupplier[v.supplierId]!.cost),
      ),
      vendors: vendors.take(_rows).toList(),
      months: [
        for (final m in byMonth.keys.toList()..sort())
          (month: m, costMinor: money(byMonth[m]!)),
      ],
      categoryCount: categories.length,
      categories: [
        for (final e in categories.take(_rows))
          (
            category: e.key,
            documents: e.value.documents,
            costMinor: money(e.value.cost),
          ),
      ],
      cohorts: {
        for (final c in PayableCohort.values)
          c: (
            count: due.where((d) => d.cohort == c).length,
            minor: money(
              due
                  .where((d) => d.cohort == c)
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
      punctuality: punctuality,
      lagDocuments: lagged.length,
      lagUndated: bills.length - lagged.length,
      lagDays: lagged.fold<int>(0, (s, l) => s + l.days),
      lagMedianDays: _percentile([for (final l in lagged) l.days], 0.5),
      lagP90Days: _percentile([for (final l in lagged) l.days], 0.9),
      lags: lags,
      quality: {
        if (mixed) KpiQuality.unavailable,
        if (partial) KpiQuality.partial,
      },
      reasons: [if (mixed) 'currency_mix', if (partial) 'period_not_over'],
      computedAt: now,
    );
  }
}
