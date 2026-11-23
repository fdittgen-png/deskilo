// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- the words of item groups: a parameter's name, a value as a person reads it, a group in one line,
// and what a refused command says (a sub-group of a sub-group, per-piece tags without tracking by piece, a group
// still in use...). Anything else falls back to the stock's own wording.
import '../../../l10n/app_localizations.dart';
import '../domain/item_groups.dart';
import '../domain/purchase_factor.dart';
import '../domain/stock_config.dart';
import 'stock_config_text.dart';

String itemGroupParamLabel(AppLocalizations l10n, String param) => switch (param) {
  'tracking' => l10n.stockEditTracking,
  'shelf_life_days' => l10n.stockEditShelfLife,
  'tag_mode' => l10n.itemGroupTagMode,
  'inventory_unit' => l10n.stockEditInventoryUnit,
  'count_every_days' => l10n.itemGroupCountEvery,
  'min_age' => l10n.itemGroupMinAge,
  'sold_by_weight' => l10n.itemGroupSoldByWeight,
  'default_purchase_unit' => l10n.itemGroupPurchaseUnit,
  'default_purchase_factor_num' || 'default_purchase_factor_den' => l10n.itemGroupPurchaseFactor,
  'reorder_point_default' => l10n.itemGroupReorderPoint,
  'reorder_quantity_default' => l10n.itemGroupReorderQty,
  'home_zone_id' => l10n.itemGroupHomeZone,
  _ => param,
};

/// A value of [param] as a person reads it; null is "not set".
String itemGroupValueText(AppLocalizations l10n, String param, Object? value) {
  if (value == null) return l10n.itemGroupNotSet;
  return switch (param) {
    'tracking' => switch (value) {
      'lot' => l10n.stockEditTrackingLot,
      'expiry' => l10n.stockEditTrackingExpiry,
      'serial' => l10n.itemGroupTrackingSerial,
      _ => l10n.stockEditTrackingNone,
    },
    'tag_mode' => switch (value) {
      'per_batch' => l10n.itemGroupTagBatch,
      'per_unit' => l10n.itemGroupTagUnit,
      _ => l10n.itemGroupTagNone,
    },
    'sold_by_weight' => value == true ? l10n.itemGroupYes : l10n.itemGroupNo,
    _ => '$value',
  };
}

/// A group's own settings in one line.
String itemGroupSummary(AppLocalizations l10n, ItemGroup g) => [
  for (final p in itemGroupEditable)
    if (g.params[p] != null) '${itemGroupParamLabel(l10n, p)}: ${itemGroupValueText(l10n, p, g.params[p])}',
  for (final p in itemGroupProposals)
    // the factor is one number: its numerator speaks for the pair
    if (g.params[p] != null && p != 'default_purchase_factor_den')
      '${itemGroupParamLabel(l10n, p)}: ${switch (p) {
        'default_purchase_factor_num' => purchaseFactorText((g.params[p]! as num).toInt(), ((g.params['default_purchase_factor_den'] ?? 1) as num).toInt()),
        'home_zone_id' => l10n.itemGroupYes,
        _ => g.params[p],
      }}',
].join(' · ');

/// What a skipped item's reason says.
String itemGroupReasonText(AppLocalizations l10n, String reason) => switch (reason) {
  'has_movements' => l10n.itemGroupReasonHasMovements,
  _ => reason,
};

String itemGroupProblem(AppLocalizations l10n, Object error) => switch (error) {
  StockConfigRefused(reason: 'depth') => l10n.itemGroupReasonDepth,
  StockConfigRefused(reason: 'needs_serial') => l10n.itemGroupReasonNeedsSerial,
  StockConfigRefused(reason: 'in_use') => l10n.itemGroupReasonInUse,
  StockConfigRefused(reason: 'has_subgroups') => l10n.itemGroupReasonHasSubgroups,
  StockConfigRefused(reason: 'group_unknown') => l10n.itemGroupReasonGroupUnknown,
  StockConfigRefused(reason: 'name_duplicate') => l10n.itemGroupReasonNameDuplicate,
  StockConfigRefused(reason: 'not_overridable') => l10n.itemGroupReasonNotOverridable,
  _ => stockSaveProblem(l10n, error),
};
