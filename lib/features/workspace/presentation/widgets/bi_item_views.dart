// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 4 — how the item figures read: what the items cost and from
// whom, the margin each product leaves under the space's cost method, how
// each supplier's prices compare, what the period cannot know, and how each
// is computed.
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_result.dart';
import '../../domain/kpi_items.dart';
import 'bi_module_section.dart';

ItemMarginsKpi? _kpi(BiMeasure m) => m.detail as ItemMarginsKpi?;

/// What every item card says about its period and its amounts.
List<String> _notes(BiMeasure m, AppLocalizations l10n) => [
  if (m.reasons.contains('currency_mix')) l10n.biFinanceCurrencyMix,
  if (m.reasons.contains('amount_not_exact')) l10n.biFinanceNotExact,
  if (m.reasons.contains('period_not_over')) l10n.biFinancePartial,
  // Those up to the period's end include the months' own.
  if (_kpi(m) case final k? when k.unresolvedCostLines > 0)
    l10n.biItemUnresolved(k.unresolvedCostLines),
];

String _method(ItemMarginsKpi k, AppLocalizations l10n) =>
    k.costMethod == 'last' ? l10n.biItemMethodLast : l10n.biItemMethodAverage;

/// The item modules' views (#3294 step 4).
final itemModuleViews = <String, BiModuleView>{
  'items.unit_prices': BiModuleView(
    title: (l10n) => l10n.biItemPricesTitle,
    value: biMoneyCell,
    basis: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => l10n.biItemPricesBasis('${k.itemLines}', '${k.itemCount}'),
      null => '',
    },
    notes: (m, l10n, locale) => _notes(m, l10n),
    details: (m, l10n, locale) => [l10n.biItemPricesDefinition],
  ),
  'items.product_margin': BiModuleView(
    title: (l10n) => l10n.biItemProductTitle,
    value: biMoneyCell,
    basis: (m, l10n, locale) => m.unknown
        ? ''
        : switch (_kpi(m)) {
            final k? => l10n.biItemProductBasis(
              biMoneyCell(k.costedRevenueMinor, locale, k.currency),
              biMoneyCell(k.salesCostMinor, locale, k.currency),
              _method(k, l10n),
            ),
            null => '',
          },
    notes: (m, l10n, locale) => [
      ..._notes(m, l10n),
      if (_kpi(m) case final k? when k.uncosted > 0)
        l10n.biItemUncosted(k.uncosted),
    ],
    details: (m, l10n, locale) => [l10n.biItemProductDefinition],
  ),
  'items.vendor_margin': BiModuleView(
    title: (l10n) => l10n.biItemVendorTitle,
    value: biMoneyCell,
    basis: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => l10n.biItemVendorBasis(k.supplierCount),
      null => '',
    },
    notes: (m, l10n, locale) => _notes(m, l10n),
    details: (m, l10n, locale) => [l10n.biItemVendorDefinition],
  ),
};
