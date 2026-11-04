// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 4 — the item figures of a Demo space, computed over that
// space's own purchase lines naming an item and its sales, by the server's
// rules (0675): a line costs its net plus the tax that cannot be recovered,
// one unit's cost is the average of every purchase of the item up to the
// period's end (the Demo keeps the default method), a supplier's margin is
// the item's sale price of the months minus its unit price, times the units
// bought. The Demo's consumptions are its invoice lines named after a
// catalogue item: it files no consumption events of its own.
import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/service_item.dart';
import '../../../features/money/domain/vat_rate.dart';
import '../../../features/workspace/domain/kpi_contract.dart';
import '../../../features/workspace/domain/kpi_items.dart';
import '../../time/date_text.dart';
import 'purchase_repository.dart';

class DemoItemKpiRepository implements ItemKpiRepository {
  DemoItemKpiRepository({
    required this.purchases,
    required this.invoices,
    required this.services,
    required this.now,
    this.currency = 'EUR',
  });

  final FakePurchaseRepository purchases;
  final List<Invoice> Function() invoices;
  final List<ServiceItem> Function() services;
  final DateTime now;
  final String currency;

  /// A technical bound on the listed rows, as on the server.
  static const _rows = 20;

  static String _month(DateTime d) => yearMonth(d.year, d.month);

  static int _cost(PurchaseLine l) => switch (l.netCents) {
    null => l.grossCents,
    final net => switch (l.recoverableTaxCents) {
      null => net + (l.taxCents ?? 0),
      final recoverable => net + (l.taxCents ?? 0) - recoverable,
    },
  };

  @override
  Future<ItemMarginsKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    bool inRange(String m) =>
        m.compareTo(fromMonth) >= 0 && m.compareTo(toMonth) <= 0;
    final names = {for (final s in services()) s.id: s.name};
    final byName = {for (final s in services()) s.name: s.id};

    final lines = [
      for (final d in purchases.documents)
        if (d.summary.state == PurchaseState.approved &&
            d.summary.kind != PurchaseKind.creditNote)
          if (d.summary.originalDate ?? d.summary.receivedOn case final dated?)
            if (_month(dated).compareTo(toMonth) <= 0)
              for (final l in d.lines)
                if (l.serviceId case final item? when names.containsKey(item))
                  (
                    item: item,
                    supplier: d.summary.supplierId,
                    supplierName: d.supplierName ?? '',
                    currency: d.summary.currency,
                    inRange: inRange(_month(dated)),
                    qty: l.quantity,
                    cost: _cost(l),
                  ),
    ];
    final sold = <String, ({double units, int net})>{};
    for (final i in invoices()) {
      if (i.isVoided || i.period == null || !inRange(i.period!)) continue;
      for (final l in i.lines) {
        final item = byName[l.label];
        if (item == null) continue;
        final was = sold[item] ?? (units: 0, net: 0);
        sold[item] = (
          units: was.units + l.quantity,
          net:
              was.net +
              (l.netCents ?? vatSplit(l.amountCents, l.vatPercent).netCents),
        );
      }
    }
    final mixed = lines.any((l) => l.currency != currency);
    int? money(num v) => mixed ? null : v.round();

    final unitCost = <String, double>{};
    final totals = <String, ({double qty, int cost})>{};
    for (final l in lines) {
      final t = totals[l.item] ?? (qty: 0, cost: 0);
      totals[l.item] = (qty: t.qty + l.qty, cost: t.cost + l.cost);
    }
    totals.forEach((item, t) {
      if (t.qty > 0) unitCost[item] = t.cost / t.qty;
    });

    final pairs =
        <(String, String?), ({double units, int cost, String supplier})>{};
    for (final l in lines.where((l) => l.inRange)) {
      final key = (l.item, l.supplier);
      final p = pairs[key] ?? (units: 0, cost: 0, supplier: l.supplierName);
      pairs[key] = (
        units: p.units + l.qty,
        cost: p.cost + l.cost,
        supplier: p.supplier,
      );
    }
    final priceRows = pairs.entries.toList()
      ..sort((a, b) {
        final c = b.value.cost.compareTo(a.value.cost);
        return c != 0 ? c : a.key.$1.compareTo(b.key.$1);
      });

    final productRows =
        [
          for (final e in sold.entries)
            (
              item: e.key,
              units: e.value.units,
              net: e.value.net,
              cogs: switch (unitCost[e.key]) {
                final c? => (e.value.units * c).round(),
                null => null,
              },
            ),
        ]..sort((a, b) {
          final c = b.net.compareTo(a.net);
          return c != 0 ? c : a.item.compareTo(b.item);
        });

    final perSupplier =
        <
          String,
          ({String name, double units, double unsold, int cost, double margin})
        >{};
    for (final e in pairs.entries) {
      final supplier = e.key.$2;
      if (supplier == null) continue;
      final s = sold[e.key.$1];
      final saleUnit = s == null || s.units == 0 ? null : s.net / s.units;
      final was =
          perSupplier[supplier] ??
          (name: e.value.supplier, units: 0, unsold: 0, cost: 0, margin: 0);
      perSupplier[supplier] = saleUnit == null
          ? (
              name: was.name,
              units: was.units,
              unsold: was.unsold + e.value.units,
              cost: was.cost,
              margin: was.margin,
            )
          : (
              name: was.name,
              units: was.units + e.value.units,
              unsold: was.unsold,
              cost: was.cost + e.value.cost,
              margin: was.margin + saleUnit * e.value.units - e.value.cost,
            );
    }
    final vendorRows = perSupplier.entries.toList()
      ..sort((a, b) {
        final c = b.value.margin.compareTo(a.value.margin);
        return c != 0 ? c : a.value.name.compareTo(b.value.name);
      });

    final costed = productRows.where((p) => p.cogs != null);
    final partial = toMonth.compareTo(_month(now)) >= 0;
    return ItemMarginsKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: currency,
      costMethod: 'average',
      itemCount: {for (final k in pairs.keys) k.$1}.length,
      itemLines: lines.where((l) => l.inRange).length,
      purchaseCostMinor: money(pairs.values.fold<int>(0, (s, p) => s + p.cost)),
      prices: [
        for (final e in priceRows.take(_rows))
          (
            itemId: e.key.$1,
            item: names[e.key.$1]!,
            supplierId: e.key.$2,
            supplier: e.value.supplier,
            units: e.value.units,
            costMinor: money(e.value.cost),
            unitPriceMinor: money(e.value.cost / e.value.units),
          ),
      ],
      productCount: productRows.length,
      uncosted: productRows.where((p) => p.cogs == null).length,
      revenueMinor: money(productRows.fold<int>(0, (s, p) => s + p.net)),
      salesCostMinor: money(costed.fold<int>(0, (s, p) => s + p.cogs!)),
      productMarginMinor: money(
        costed.fold<int>(0, (s, p) => s + p.net - p.cogs!),
      ),
      products: [
        for (final p in productRows.take(_rows))
          (
            itemId: p.item,
            item: names[p.item]!,
            units: p.units,
            revenueMinor: money(p.net),
            unitCostMinor: switch (unitCost[p.item]) {
              final c? => money(c),
              null => null,
            },
            costMinor: p.cogs == null ? null : money(p.cogs!),
            marginMinor: p.cogs == null ? null : money(p.net - p.cogs!),
          ),
      ],
      supplierCount: vendorRows.length,
      vendorMarginMinor: money(
        vendorRows.fold<int>(0, (s, v) => s + v.value.margin.round()),
      ),
      vendors: [
        for (final v in vendorRows)
          (
            supplierId: v.key,
            supplier: v.value.name,
            units: v.value.units,
            unsoldUnits: v.value.unsold,
            costMinor: money(v.value.cost),
            marginMinor: money(v.value.margin),
          ),
      ],
      quality: {
        if (mixed) KpiQuality.unavailable,
        if (partial) KpiQuality.partial,
      },
      reasons: [if (mixed) 'currency_mix', if (partial) 'period_not_over'],
      computedAt: now,
    );
  }
}
