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
    _receivingReason(l10n, reason) ??
    _operationReason(l10n, reason) ??
    _groupReason(l10n, reason) ??
    _tagReason(l10n, reason) ??
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
  'level_parent_wrong' => l10n.stockReasonLevelParentWrong,
  'level_parent_missing' => l10n.stockReasonLevelParentMissing,
  'level_children_wrong' => l10n.stockReasonLevelChildrenWrong,
  'pick_role_unknown' => l10n.stockReasonPickRoleUnknown,
  'mapping_unknown' => l10n.stockReasonMappingUnknown,
  'site_unknown' => l10n.stockReasonSiteUnknown,
  'point_fixed' => l10n.stockReasonPointFixed,
  'quantity_and_target' => l10n.stockReasonQuantityAndTarget,
  'target_below_point' => l10n.stockReasonTargetBelowPoint,
  'point_twice' => l10n.stockReasonPointTwice,
  'home_invalid' => l10n.stockReasonHomeInvalid,
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

String? _receivingReason(AppLocalizations l10n, String reason) => switch (reason) {
  'over_allocated' => l10n.stockReasonOverAllocated,
  'line_unknown' => l10n.stockReasonLineUnknown,
  'line_conflict' => l10n.stockReasonLineConflict,
  'item_not_stocked' => l10n.stockReasonItemNotStocked,
  'unit_unmapped' => l10n.stockReasonUnitUnmapped,
  'quantity_invalid' => l10n.stockReasonQuantityInvalid,
  'variant_required' => l10n.stockReasonVariantRequired,
  'lot_code_required' => l10n.stockReasonLotCodeRequired,
  'expiry_required' => l10n.stockReasonExpiryRequired,
  'expiry_malformed' => l10n.stockReasonExpiryMalformed,
  'cost_invalid' => l10n.stockReasonCostInvalid,
  'cost_rate_missing' => l10n.stockReasonCostRateMissing,
  'lot_group_conflict' => l10n.stockReasonLotGroupConflict,
  'receipt_unknown' => l10n.stockReasonReceiptUnknown,
  'location_foreign' => l10n.stockReasonLocationForeign,
  _ => null,
};

String? _operationReason(AppLocalizations l10n, String reason) => switch (reason) {
  'reason_places' => l10n.stockReasonReasonPlaces,
  'transit_is_system' => l10n.stockReasonTransitIsSystem,
  'transfer_needs_transit' => l10n.stockReasonTransferNeedsTransit,
  'lot_expired' => l10n.stockReasonLotExpired,
  'one_source' => l10n.stockReasonOneSource,
  'receive_over' => l10n.stockReasonReceiveOver,
  'wrong_site' => l10n.stockReasonWrongSite,
  'same_site' => l10n.stockReasonSameSite,
  'transfer_unknown' => l10n.stockReasonTransferUnknown,
  _ => null,
};

/// What a failed save says: a stale read, a unit the first movement fixed, a
/// refusal with its reason, or (anything else) that nothing was saved.
String stockSaveProblem(AppLocalizations l10n, Object error) => switch (error) {
  StockConfigStale() => l10n.stockEditStale,
  StockConfigInUse() => l10n.stockEditInUse,
  StockNotEnough() => l10n.refusalStockNotEnough,
  StockConfigRefused(:final reason) => stockReasonText(l10n, reason),
  _ => l10n.stockEditNotSaved,
};

/// #4361 -- the reasons of the item groups.
String? _groupReason(AppLocalizations l10n, String reason) => switch (reason) {
  'depth' => l10n.stockReasonGroupDepth,
  'needs_serial' || 'per_unit_needs_serial' => l10n.stockReasonGroupNeedsSerial,
  'name_duplicate' => l10n.stockReasonGroupNameDuplicate,
  'name_length' => l10n.stockReasonGroupNameLength,
  'required' => l10n.stockReasonGroupNameRequired,
  'group_unknown' => l10n.stockReasonGroupUnknown,
  'unknown_reference' => l10n.stockReasonGroupUnknownReference,
  'has_subgroups' => l10n.stockReasonGroupHasSubgroups,
  'in_use' => l10n.stockReasonGroupInUse,
  'not_overridable' => l10n.stockReasonGroupNotOverridable,
  'value_required' => l10n.stockReasonGroupValueRequired,
  'vat_rate_unknown' => l10n.stockReasonGroupVatRateUnknown,
  'place_unknown' => l10n.stockReasonGroupPlaceUnknown,
  'item_unknown' => l10n.stockReasonGroupItemUnknown,
  'has_movements' => l10n.stockReasonGroupHasMovements,
  _ => null,
};

/// #4362 -- the reasons of the tags and the named pieces.
String? _tagReason(AppLocalizations l10n, String reason) => switch (reason) {
  'has_tags' => l10n.stockReasonHasTags,
  'tag_mode_none' => l10n.stockReasonTagModeNone,
  'tag_per_unit_item' => l10n.stockReasonTagPerUnitItem,
  'tag_malformed' => l10n.stockReasonTagMalformed,
  'tag_owner_unknown' => l10n.stockReasonTagOwnerUnknown,
  'tag_owner_inactive' => l10n.stockReasonTagOwnerInactive,
  'units_not_tracked' => l10n.stockReasonUnitsNotTracked,
  _ => null,
};
