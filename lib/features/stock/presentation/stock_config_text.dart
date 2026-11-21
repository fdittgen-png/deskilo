// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1) -- the words of a refusal: the server's reason, said in the
// reader's language under the field it names.
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';

/// The text of [reason] (`code_duplicate`, `factor_invalid`, ...).
String stockReasonText(AppLocalizations l10n, String reason) =>
    _itemReason(l10n, reason) ??
    _placeReason(l10n, reason) ??
    _variantReason(l10n, reason) ??
    l10n.stockReasonOther;

String? _itemReason(AppLocalizations l10n, String reason) => switch (reason) {
  'unit_unknown' => l10n.stockReasonUnitUnknown,
  'unit_duplicate' => l10n.stockReasonUnitDuplicate,
  'factor_invalid' => l10n.stockReasonFactorInvalid,
  'default_purchase_twice' => l10n.stockReasonDefaultPurchaseTwice,
  'default_sale_twice' => l10n.stockReasonDefaultSaleTwice,
  'code_malformed' => l10n.stockReasonCodeMalformed,
  'code_duplicate' => l10n.stockReasonCodeDuplicate,
  'gtin_length' => l10n.stockReasonGtinLength,
  'gtin_check' => l10n.stockReasonGtinCheck,
  'registry_unit' => l10n.stockReasonRegistryUnit,
  'dimension_mismatch' => l10n.stockReasonDimensionMismatch,
  'stock_on_hand' => l10n.stockReasonStockOnHand,
  'tracking_unsupported' => l10n.stockReasonTrackingUnsupported,
  'out_of_range' => l10n.stockReasonOutOfRange,
  _ => null,
};

String? _placeReason(AppLocalizations l10n, String reason) => switch (reason) {
  'too_long' => l10n.stockReasonTooLong,
  'kind_unknown' => l10n.stockReasonKindUnknown,
  'location_cycle' => l10n.stockReasonLocationCycle,
  'location_parent_foreign' => l10n.stockReasonLocationParentForeign,
  'location_virtual' => l10n.stockReasonLocationVirtual,
  'parent_inactive' => l10n.stockReasonParentInactive,
  'location_occupied' => l10n.stockReasonLocationOccupied,
  'location_has_children' => l10n.stockReasonLocationHasChildren,
  'location_default' => l10n.stockReasonLocationDefault,
  _ => null,
};

String? _variantReason(AppLocalizations l10n, String reason) => switch (reason) {
  'variant_unknown' => l10n.stockReasonVariantUnknown,
  'variant_combination_duplicate' => l10n.stockReasonCombinationDuplicate,
  'variant_values_missing' => l10n.stockReasonValuesMissing,
  'value_foreign' => l10n.stockReasonValueForeign,
  'price_invalid' => l10n.stockReasonPriceInvalid,
  'variant_in_use' => l10n.stockReasonVariantInUse,
  'variant_has_stock' => l10n.stockReasonVariantHasStock,
  'stock_without_variant' => l10n.stockReasonStockWithoutVariant,
  'name_malformed' => l10n.stockReasonNameMalformed,
  'name_duplicate' => l10n.stockReasonNameDuplicate,
  'supplier_foreign' => l10n.stockReasonSupplierForeign,
  'item_foreign' => l10n.stockReasonItemForeign,
  'mapping_duplicate' => l10n.stockReasonMappingDuplicate,
  'unit_not_of_item' => l10n.stockReasonUnitNotOfItem,
  'unit_in_use' => l10n.stockReasonUnitInUse,
  'code_unit_removed' => l10n.stockReasonCodeUnitRemoved,
  'malformed' => l10n.stockReasonMalformed,
  _ => null,
};

/// What a failed save says: a stale read, a unit the first movement fixed, a
/// refusal with its reason, or (anything else) that nothing was saved.
String stockSaveProblem(AppLocalizations l10n, Object error) => switch (error) {
  StockConfigStale() => l10n.stockEditStale,
  StockConfigInUse() => l10n.stockEditInUse,
  StockConfigRefused(:final reason) => stockReasonText(l10n, reason),
  _ => l10n.stockEditNotSaved,
};
