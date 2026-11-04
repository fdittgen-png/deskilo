// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 4 — the item side of the figures, on the KPI contract
// (#1918): what an item costs from each supplier, the margin each product
// leaves when it is sold, and the margin each supplier's price leaves. The
// SERVER computes them (`kpi_item_margins`, 0675) from the purchase lines
// that name an item and the confirmed consumptions; this layer names what
// it returns.
//
//   * a line costs its net plus the tax that cannot be recovered; credit
//     notes set no unit cost;
//   * one unit's cost follows the workspace's method
//     (`purchase.item_cost_method`): the average of every purchase up to
//     the period's end, or the last one dated by then;
//   * a product's revenue is its consumptions' net, by billing month;
//   * amounts are minor units of the workspace currency (a unit price
//     rounded to the minor unit); another currency in scope leaves them
//     unknown (`currency_mix`), never summed.
//
// Pure Dart: no Flutter, no l10n.
library;

import '../../../core/data/json_reader.dart';
import 'kpi_contract.dart';

const _unitPricesKpi = KpiDefinition(
  id: 'items.unit_prices',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the approved purchase lines naming an item, dated in whole months '
      '[from, to]: their cost, units and unit price by item and supplier',
  dateBasis: KpiDateBasis.documentDate,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'cost_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: [
    'purchases',
    'items on purchase lines',
    'the workspace currency',
  ],
  minCohort: null,
);

const _productMarginKpi = KpiDefinition(
  id: 'items.product_margin',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the confirmed consumptions of items billed in whole months [from, '
      'to]: their net revenue minus their units at the unit cost of the '
      'workspace\'s method, at the period\'s end',
  dateBasis: KpiDateBasis.invoiceMonth,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'margin_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: [
    'services',
    'items on purchase lines',
    'the workspace currency',
  ],
  minCohort: null,
);

const _vendorMarginKpi = KpiDefinition(
  id: 'items.vendor_margin',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the items bought in whole months [from, to], by supplier: the '
      'item\'s sale price of the months minus the supplier\'s unit price, '
      'times the units bought',
  dateBasis: KpiDateBasis.documentDate,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'margin_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: [
    'purchases',
    'items on purchase lines',
    'the workspace currency',
  ],
  minCohort: null,
);

/// The item figures, in catalogue order.
const itemKpis = <KpiDefinition>[
  _unitPricesKpi,
  _productMarginKpi,
  _vendorMarginKpi,
];

/// One item from one supplier in the months. [supplierId] is null for a
/// member's receipt.
typedef ItemPrice = ({
  String itemId,
  String item,
  String? supplierId,
  String supplier,
  double units,
  int? costMinor,
  int? unitPriceMinor,
});

/// One product sold in the months; the cost and margin are null when the
/// item was never bought.
typedef ProductMargin = ({
  String itemId,
  String item,
  double units,
  int? revenueMinor,
  int? unitCostMinor,
  int? costMinor,
  int? marginMinor,
});

/// What one supplier's prices leave against the items' sale prices.
typedef VendorMargin = ({
  String supplierId,
  String supplier,
  double units,
  double unsoldUnits,
  int? costMinor,
  int? marginMinor,
});

/// What `kpi_item_margins` returned for the whole months
/// [fromMonth, toMonth], typed. A missing amount is null, never 0.
class ItemMarginsKpi {
  const ItemMarginsKpi({
    required this.fromMonth,
    required this.toMonth,
    required this.currency,
    required this.costMethod,
    required this.itemCount,
    required this.itemLines,
    required this.purchaseCostMinor,
    required this.prices,
    required this.productCount,
    required this.uncosted,
    required this.revenueMinor,
    required this.salesCostMinor,
    required this.productMarginMinor,
    required this.products,
    required this.supplierCount,
    required this.vendorMarginMinor,
    required this.vendors,
    required this.quality,
    required this.reasons,
    required this.computedAt,
  });

  final String fromMonth;
  final String toMonth;
  final String currency;

  /// `average` or `last` (`purchase.item_cost_method`).
  final String costMethod;

  final int itemCount;
  final int itemLines;
  final int? purchaseCostMinor;
  final List<ItemPrice> prices;

  final int productCount;

  /// Products sold but never bought: no cost, no margin.
  final int uncosted;
  final int? revenueMinor;
  final int? salesCostMinor;
  final int? productMarginMinor;
  final List<ProductMargin> products;

  final int supplierCount;
  final int? vendorMarginMinor;
  final List<VendorMargin> vendors;

  final Set<KpiQuality> quality;
  final List<String> reasons;
  final DateTime computedAt;
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
ItemMarginsKpi itemMarginsFromJson(Map<String, Object?> json) {
  final r = JsonReader(json, context: 'kpi_item_margins');
  var inexact = false;
  // A null amount is unknown on purpose (another currency in scope, an item
  // never bought); only a present value that cannot travel exactly is
  // inexact.
  int? minor(JsonReader row, String key) {
    final raw = row.raw(key);
    final v = exactMinor(raw);
    if (raw != null && v == null) inexact = true;
    return v;
  }

  final prices = _object(r, 'unit_prices');
  final products = _object(r, 'products');
  final vendors = _object(r, 'vendors');
  final priceRows = prices.objects(
    'rows',
    (row) => (
      itemId: row.string('item_id'),
      item: row.stringOr('item'),
      supplierId: row.stringOrNull('supplier_id'),
      supplier: row.stringOr('supplier'),
      units: row.doubleOrNull('units') ?? 0,
      costMinor: minor(row, 'cost_minor'),
      unitPriceMinor: minor(row, 'unit_price_minor'),
    ),
  );
  final productRows = products.objects(
    'rows',
    (row) => (
      itemId: row.string('item_id'),
      item: row.stringOr('item'),
      units: row.doubleOrNull('units') ?? 0,
      revenueMinor: minor(row, 'revenue_minor'),
      unitCostMinor: minor(row, 'unit_cost_minor'),
      costMinor: minor(row, 'cost_minor'),
      marginMinor: minor(row, 'margin_minor'),
    ),
  );
  final vendorRows = vendors.objects(
    'rows',
    (row) => (
      supplierId: row.string('supplier_id'),
      supplier: row.stringOr('supplier'),
      units: row.doubleOrNull('units') ?? 0,
      unsoldUnits: row.doubleOrNull('unsold_units') ?? 0,
      costMinor: minor(row, 'cost_minor'),
      marginMinor: minor(row, 'margin_minor'),
    ),
  );
  final purchaseCost = minor(prices, 'cost_minor');
  final revenue = minor(products, 'revenue_minor');
  final salesCost = minor(products, 'cost_minor');
  final productMargin = minor(products, 'margin_minor');
  final vendorMargin = minor(vendors, 'margin_minor');
  final currency = r.stringOr('currency');
  return ItemMarginsKpi(
    fromMonth: r.stringOr('from'),
    toMonth: r.stringOr('to'),
    currency: currency,
    costMethod: r.stringOr('cost_method', 'average'),
    itemCount: _count(prices, 'items'),
    itemLines: _count(prices, 'lines'),
    purchaseCostMinor: purchaseCost,
    prices: priceRows,
    productCount: _count(products, 'items'),
    uncosted: _count(products, 'uncosted'),
    revenueMinor: revenue,
    salesCostMinor: salesCost,
    productMarginMinor: productMargin,
    products: productRows,
    supplierCount: _count(vendors, 'suppliers'),
    vendorMarginMinor: vendorMargin,
    vendors: vendorRows,
    quality: {
      for (final q in r.strings('quality'))
        kpiQualityOf(q) ?? KpiQuality.unavailable,
      if (inexact || currency.isEmpty) KpiQuality.unavailable,
    },
    reasons: [...r.strings('reasons'), if (inexact) 'amount_not_exact'],
    computedAt: r.dateTime('computed_at'),
  );
}

/// Reads the item figures (#3294 step 4). Every call is authorized there.
abstract interface class ItemKpiRepository {
  /// The figures of the whole months [fromMonth, toMonth] (`YYYY-MM`).
  Future<ItemMarginsKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  });
}
