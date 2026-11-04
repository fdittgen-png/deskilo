// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 4 — the item figures of the analytics page, read from
// `kpi_item_margins` (0675): one read per workspace and months, shared by
// the three cards, turned into the page's measure and its table rows.
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/bi_query.dart';
import '../domain/bi_result.dart';
import '../domain/kpi_contract.dart';
import '../domain/kpi_items.dart';
import 'bi_providers.dart';
import 'item_kpi_providers.dart';

/// The figure [moduleId] shows of [k]; null is unknown, never 0.
int? _figure(ItemMarginsKpi k, String moduleId) => switch (moduleId) {
  'items.product_margin' => k.productMarginMinor,
  'items.vendor_margin' => k.vendorMarginMinor,
  _ => k.purchaseCostMinor,
};

/// #3294 — one item figure of [k]. Unknown when the amount is (another
/// currency, an inexact amount).
@visibleForTesting
BiMeasure itemMeasure(
  ItemMarginsKpi k,
  String moduleId, {
  bool currencyCompatible = true,
}) {
  final value = _figure(k, moduleId);
  final quality = {
    ...k.quality,
    if (value == null || !currencyCompatible) KpiQuality.unavailable,
  };
  final unknown = quality.contains(KpiQuality.unavailable);
  return BiMeasure(
    numerator: value ?? 0,
    quality: {...quality, if (!unknown && value == 0) KpiQuality.knownZero},
    reasons: [...k.reasons, if (!currencyCompatible) 'currency_mix'],
    detail: k,
  );
}

BiMeasure _row(ItemMarginsKpi k, int? amount) => BiMeasure(
  numerator: amount ?? 0,
  quality: {if (amount == null) KpiQuality.unavailable},
  detail: k,
);

/// The table's rows of [moduleId]: an item from a supplier at its unit
/// price, a product with its margin, or a supplier with the margin its
/// prices leave. Each carries its own names.
@visibleForTesting
List<BiRow> itemRows(ItemMarginsKpi k, String moduleId) => switch (moduleId) {
  'items.product_margin' => [
    for (final p in k.products)
      BiRow(
        key: 'item-${p.itemId}',
        label: p.item,
        current: _row(k, p.marginMinor),
      ),
  ],
  'items.vendor_margin' => [
    for (final v in k.vendors)
      BiRow(
        key: 'supplier-${v.supplierId}',
        label: v.supplier,
        current: _row(k, v.marginMinor),
      ),
  ],
  _ => [
    for (final p in k.prices)
      BiRow(
        key: 'price-${p.itemId}-${p.supplierId ?? ''}',
        label: p.supplier.isEmpty ? p.item : '${p.item} · ${p.supplier}',
        current: _row(k, p.unitPriceMinor),
      ),
  ],
};

/// The item module [moduleId] over [period], against [compared].
Future<BiResult> biItemResult(
  Ref ref,
  String workspaceId,
  String moduleId,
  BiPeriod period,
  BiPeriod? compared,
) async {
  Future<ItemMarginsKpi> watch(BiPeriod p) {
    final m = biMonths(p);
    return ref.watch(itemMarginsProvider(workspaceId, m.from, m.to).future);
  }

  // Both watched before the first await (provider_watch_before_await).
  final now = watch(period);
  final then = compared == null ? null : watch(compared);
  final current = await now;
  final before = then == null ? null : await then;
  final currencies = {current.currency, ?before?.currency};
  final compatible = currencies.length == 1 && current.currency.isNotEmpty;
  return BiResult(
    period: period,
    comparedPeriod: compared,
    total: BiRow(
      key: BiRow.totalKey,
      label: null,
      current: itemMeasure(current, moduleId, currencyCompatible: compatible),
      compared: before == null
          ? null
          : itemMeasure(before, moduleId, currencyCompatible: compatible),
    ),
    groups: itemRows(current, moduleId),
    computedAt: current.computedAt,
    currency: compatible ? current.currency : null,
  );
}
