// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- the words of item groups: a parameter's name, a value as a person reads it, a group in one line,
// and why an item was skipped. What a refused command says is the stock's one wording (stock_config_text.dart).
import '../../../core/i18n/rate_format.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/item_groups.dart';
import '../domain/purchase_factor.dart';

/// The names of the till's parameters of an item group, as the server keeps them.
const groupParamCategory = 'till_category';
const groupParamColour = 'quick_key_colour';
const groupParamDepositItem = 'deposit_item_id';
const groupParamDepositMinor = 'deposit_minor';
const groupParamLabelTemplate = 'label_template';

String itemGroupParamLabel(AppLocalizations l10n, String param) => switch (param) {
  'tracking' => l10n.stockEditTracking,
  'shelf_life_days' => l10n.stockEditShelfLife,
  'tag_mode' => l10n.itemGroupTagMode,
  'inventory_unit' => l10n.stockEditInventoryUnit,
  'count_every_days' => l10n.itemGroupCountEvery,
  'min_age' => l10n.itemGroupMinAge,
  'sold_by_weight' => l10n.itemGroupSoldByWeight,
  groupParamCategory => l10n.itemGroupTillCategory,
  groupParamColour => l10n.itemGroupKeyColour,
  groupParamDepositItem => l10n.itemGroupDepositItem,
  groupParamDepositMinor => l10n.itemGroupDepositAmount,
  groupParamLabelTemplate => l10n.itemGroupLabelTemplate,
  'default_purchase_unit' => l10n.itemGroupPurchaseUnit,
  'default_purchase_factor_num' || 'default_purchase_factor_den' => l10n.itemGroupPurchaseFactor,
  'reorder_point_default' => l10n.itemGroupReorderPoint,
  'reorder_quantity_default' => l10n.itemGroupReorderQty,
  'home_zone_id' => l10n.itemGroupHomeZone,
  'vat_rate_id' => l10n.vatServiceRate,
  'supply_class' => l10n.itemGroupSupply,
  'price_rounding' => l10n.itemGroupRounding,
  'target_margin_bps' => l10n.itemGroupMargin,
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
    'supply_class' => value == 'property' ? l10n.itemGroupSupplyProperty : l10n.itemGroupSupplyGeneral,
    'price_rounding' => value == 'none' ? l10n.itemGroupRoundingNone : '$value',
    'target_margin_bps' => ratePercentText((value as num) / 100, locale: l10n.localeName),
    'vat_rate_id' || 'home_zone_id' || groupParamDepositItem => l10n.itemGroupSet,
    _ => '$value',
  };
}

/// A group's own settings in one line.
String itemGroupSummary(AppLocalizations l10n, ItemGroup g) => [
  for (final p in itemGroupEditable)
    if (g.params[p] != null) l10n.labelWithValue(itemGroupParamLabel(l10n, p), itemGroupValueText(l10n, p, g.params[p])),
  for (final p in itemGroupProposals)
    // the factor is one number: its numerator speaks for the pair
    if (g.params[p] != null && p != 'default_purchase_factor_den') l10n.labelWithValue(itemGroupParamLabel(l10n, p), _proposalText(l10n, g, p)),
].join(' · ');

/// A proposal of [g] as a person reads it: the factor as one number or a fraction, the home zone as set.
String _proposalText(AppLocalizations l10n, ItemGroup g, String p) => switch (p) {
  'default_purchase_factor_num' => purchaseFactorText((g.params[p]! as num).toInt(), ((g.params['default_purchase_factor_den'] ?? 1) as num).toInt()),
  'home_zone_id' || 'target_margin_bps' || 'price_rounding' => itemGroupValueText(l10n, p, g.params[p]),
  _ => '${g.params[p]}',
};

/// What a skipped item's reason says.
String itemGroupReasonText(AppLocalizations l10n, String reason) => switch (reason) {
  'has_movements' => l10n.itemGroupReasonHasMovements,
  _ => reason,
};
