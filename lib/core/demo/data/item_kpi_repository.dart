// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 4 — the item figures of a Demo space, computed over that
// space's own purchase lines naming an item and its sales, by the server's
// rules (0675): a line costs its net plus the tax that cannot be recovered,
// one unit's cost is the average of every purchase of the item up to the
// period's end (the Demo keeps the default method), a supplier is compared
// by what its units cost above the lowest unit price paid for the item (no
// supplier margin: no sale names the purchase it consumed). A Demo purchase
// line names its item by id or not at all, so none is unresolved. The
// Demo's consumptions are its invoice lines named after a catalogue item:
// it files no consumption events of its own.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/service_item.dart';
import '../../../features/money/domain/vat_rate.dart';
import '../../../features/workspace/domain/kpi_contract.dart';
import '../../../features/workspace/domain/kpi_items.dart';
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
    final lines = _lines(names, toMonth, inRange);
    final sold = _sold(inRange);
    final mixed = lines.any((l) => l.currency != currency);
    int? money(num v) => mixed ? null : v.round();
    final unitCost = _unitCosts(lines);
    final pairs = _pairs(lines);
    final products = _products(sold, unitCost);
    final vendors = _vendors(pairs);
    final costed = products.where((p) => p.cogs != null);
    // None costed: the cost and margin are unknown, never 0.
    int? costedMoney(int Function(int s, ({int net, int? cogs}) p) add) =>
        products.isNotEmpty && costed.isEmpty
        ? null
        : money(
            costed.fold<int>(0, (s, p) => add(s, (net: p.net, cogs: p.cogs))),
          );
    final uncosted = products.length - costed.length;
    final partial = toMonth.compareTo(_month(now)) >= 0;
    return ItemMarginsKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: currency,
      costMethod: 'average',
      itemCount: {for (final k in pairs.keys) k.$1}.length,
      itemLines: lines.where((l) => l.inRange).length,
      unresolvedLines: 0,
      ambiguousLines: 0,
      purchaseCostMinor: money(pairs.values.fold<int>(0, (s, p) => s + p.cost)),
      prices: [
        for (final e in pairs.entries.take(_rows))
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
      productCount: products.length,
      uncosted: uncosted,
      unresolvedCostLines: 0,
      revenueMinor: money(products.fold<int>(0, (s, p) => s + p.net)),
      costedRevenueMinor: costedMoney((s, p) => s + p.net),
      salesCostMinor: costedMoney((s, p) => s + p.cogs!),
      productMarginMinor: costedMoney((s, p) => s + p.net - p.cogs!),
      products: [
        for (final p in products.take(_rows))
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
      supplierCount: vendors.length,
      vendorPremiumMinor: money(
        vendors.fold<int>(0, (s, v) => s + v.premium.round()),
      ),
      vendors: [
        for (final v in vendors)
          (
            supplierId: v.id,
            supplier: v.name,
            items: v.items,
            comparedItems: v.compared,
            units: v.units,
            costMinor: money(v.cost),
            premiumMinor: money(v.premium),
          ),
      ],
      quality: {
        if (mixed) KpiQuality.unavailable,
        if (partial || uncosted > 0) KpiQuality.partial,
      },
      reasons: [
        if (mixed) 'currency_mix',
        'no_consumption_link',
        if (uncosted > 0) 'uncosted_items',
        if (partial) 'period_not_over',
      ],
      computedAt: now,
    );
  }

  /// Every line of an approved bill or receipt dated up to the end of the
  /// months that names an item of the catalogue.
  List<_ItemLine> _lines(
    Map<String, String> names,
    String toMonth,
    bool Function(String month) inRange,
  ) => [
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

  /// What each item sold in the months: the invoice lines named after it.
  Map<String, ({double units, int net})> _sold(
    bool Function(String month) inRange,
  ) {
    final byName = {for (final s in services()) s.name: s.id};
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
    return sold;
  }

  /// One unit's average cost of each item, over every purchase up to the
  /// end of the months.
  static Map<String, double> _unitCosts(List<_ItemLine> lines) {
    final totals = <String, ({double qty, int cost})>{};
    for (final l in lines) {
      final t = totals[l.item] ?? (qty: 0, cost: 0);
      totals[l.item] = (qty: t.qty + l.qty, cost: t.cost + l.cost);
    }
    return {
      for (final e in totals.entries)
        if (e.value.qty > 0) e.key: e.value.cost / e.value.qty,
    };
  }

  /// The item lines of the months by item and supplier, the largest cost
  /// first.
  static Map<(String, String?), ({double units, int cost, String supplier})>
  _pairs(List<_ItemLine> lines) {
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
    final sorted = pairs.entries.toList()
      ..sort((a, b) {
        final c = b.value.cost.compareTo(a.value.cost);
        return c != 0 ? c : a.key.$1.compareTo(b.key.$1);
      });
    return Map.fromEntries(sorted);
  }

  /// Each item sold: its units, net revenue and cost of sales (null when
  /// never bought), the largest revenue first.
  static List<({String item, double units, int net, int? cogs})> _products(
    Map<String, ({double units, int net})> sold,
    Map<String, double> unitCost,
  ) =>
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

  /// Each supplier against the lowest unit price paid for the same item in
  /// the months: what its units cost above it, the largest first.
  static List<_VendorSum> _vendors(
    Map<(String, String?), ({double units, int cost, String supplier})> pairs,
  ) {
    final bought = [
      for (final e in pairs.entries)
        if (e.key.$2 case final supplier?)
          (item: e.key.$1, supplier: supplier, p: e.value),
    ];
    final lowest = <String, double>{};
    final offers = <String, int>{};
    for (final b in bought) {
      final unit = b.p.cost / b.p.units;
      final was = lowest[b.item];
      lowest[b.item] = was == null || unit < was ? unit : was;
      offers[b.item] = (offers[b.item] ?? 0) + 1;
    }
    final by = <String, _VendorSum>{};
    for (final b in bought) {
      final was =
          by[b.supplier] ??
          (
            id: b.supplier,
            name: b.p.supplier,
            items: 0,
            compared: 0,
            units: 0.0,
            cost: 0,
            premium: 0.0,
          );
      by[b.supplier] = (
        id: b.supplier,
        name: was.name,
        items: was.items + 1,
        compared: was.compared + (offers[b.item]! > 1 ? 1 : 0),
        units: was.units + b.p.units,
        cost: was.cost + b.p.cost,
        premium:
            was.premium + (b.p.cost / b.p.units - lowest[b.item]!) * b.p.units,
      );
    }
    return by.values.toList()..sort((a, b) {
      final c = b.premium.compareTo(a.premium);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
  }
}

/// One purchase line naming an item.
typedef _ItemLine = ({
  String item,
  String? supplier,
  String supplierName,
  String currency,
  bool inRange,
  double qty,
  int cost,
});

/// One supplier's items, units, cost and what they cost above the lowest
/// offers.
typedef _VendorSum = ({
  String id,
  String name,
  int items,
  int compared,
  double units,
  int cost,
  double premium,
});
