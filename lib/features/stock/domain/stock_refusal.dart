// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4402/#4403 -- why the server refused a stock configuration or movement
// (DKG11: `stock_config_refuse(field, reason)`, or the reason written in the
// refusal's JSON detail): one value each, in one place. The data boundary reads
// the server's reason into this enum; the Demo, the stock ledger and the
// domain checks name a refusal by it, and the screens word it in one function
// (`stockProblemText`). `test/parity/stock_contract_test.dart` fails when the
// SQL gains a reason that is not here, or when a value here is no longer
// raised.

/// A reason of `StockConfigRefused`, by its wire name.
enum StockRefusal {
  codeDuplicate('code_duplicate'),
  codeMalformed('code_malformed'),
  codeUnitRemoved('code_unit_removed'),
  conversionSameUnit('conversion_same_unit'),
  conversionUnknown('conversion_unknown'),
  costInvalid('cost_invalid'),
  costRateMissing('cost_rate_missing'),
  defaultPurchaseTwice('default_purchase_twice'),
  defaultSaleTwice('default_sale_twice'),
  depth('depth'),
  dimensionInvalid('dimension_invalid'),
  dimensionMismatch('dimension_mismatch'),
  eceInvalid('ece_invalid'),
  expiryMalformed('expiry_malformed'),
  expiryRequired('expiry_required'),
  factorInvalid('factor_invalid'),
  groupUnknown('group_unknown'),
  gtinCheck('gtin_check'),
  gtinLength('gtin_length'),
  hasSubgroups('has_subgroups'),
  hasTags('has_tags'),
  homeInvalid('home_invalid'),
  inUse('in_use'),
  inexact('inexact'),
  itemForeign('item_foreign'),
  itemNotStocked('item_not_stocked'),
  itemUnknown('item_unknown'),
  kindUnknown('kind_unknown'),
  labelRequired('label_required'),
  levelChildrenWrong('level_children_wrong'),
  levelParentMissing('level_parent_missing'),
  levelParentWrong('level_parent_wrong'),
  lineConflict('line_conflict'),
  lineUnknown('line_unknown'),
  locationCycle('location_cycle'),
  locationDefault('location_default'),
  locationForeign('location_foreign'),
  locationHasChildren('location_has_children'),
  locationOccupied('location_occupied'),
  locationParentForeign('location_parent_foreign'),
  locationVirtual('location_virtual'),
  lotCodeRequired('lot_code_required'),
  lotExpired('lot_expired'),
  lotGroupConflict('lot_group_conflict'),
  malformed('malformed'),
  mappingDuplicate('mapping_duplicate'),
  mappingUnknown('mapping_unknown'),
  nameDuplicate('name_duplicate'),
  nameLength('name_length'),
  nameMalformed('name_malformed'),
  needsSerial('needs_serial'),
  notOverridable('not_overridable'),
  oneSource('one_source'),
  oneSubject('one_subject'),
  outOfRange('out_of_range'),
  packageUnit('package_unit'),
  overAllocated('over_allocated'),
  parentInactive('parent_inactive'),
  pickRoleUnknown('pick_role_unknown'),
  placeUnknown('place_unknown'),
  placeUnusable('place_unusable'),
  pointFixed('point_fixed'),
  pointTwice('point_twice'),
  preferredTwice('preferred_twice'),
  priceInvalid('price_invalid'),
  quantityAndTarget('quantity_and_target'),
  quantityInvalid('quantity_invalid'),
  reasonPlaces('reason_places'),
  receiptUnknown('receipt_unknown'),
  receiveOver('receive_over'),
  registryUnit('registry_unit'),
  required('required'),
  sameSite('same_site'),
  siteUnknown('site_unknown'),
  stockOnHand('stock_on_hand'),
  stockWithoutVariant('stock_without_variant'),
  supplierForeign('supplier_foreign'),
  tagMalformed('tag_malformed'),
  tagModeNone('tag_mode_none'),
  tagOwnerInactive('tag_owner_inactive'),
  tagOwnerUnknown('tag_owner_unknown'),
  tagPerUnitItem('tag_per_unit_item'),
  tagsOff('tags_off'),
  targetBelowPoint('target_below_point'),
  tooLong('too_long'),
  trackingUnsupported('tracking_unsupported'),
  transferNeedsTransit('transfer_needs_transit'),
  transferUnknown('transfer_unknown'),
  transitIsSystem('transit_is_system'),
  unitArchived('unit_archived'),
  unitDuplicate('unit_duplicate'),
  unitFixed('unit_fixed'),
  unitInUse('unit_in_use'),
  unitNotOfItem('unit_not_of_item'),
  unitUnknown('unit_unknown'),
  unitUnmapped('unit_unmapped'),
  unitsNotTracked('units_not_tracked'),
  unknown('unknown'),
  unknownReference('unknown_reference'),
  valueForeign('value_foreign'),
  valueRequired('value_required'),
  variantCombinationDuplicate('variant_combination_duplicate'),
  variantHasStock('variant_has_stock'),
  variantInUse('variant_in_use'),
  variantRequired('variant_required'),
  variantUnknown('variant_unknown'),
  variantValuesMissing('variant_values_missing'),
  vatRateUnknown('vat_rate_unknown'),
  wrongSite('wrong_site'),

  /// A reason this build does not know: worded as the generic refusal it came
  /// as, never taken for another reason. The server never writes it.
  other('');

  const StockRefusal(this.wire);

  /// The reason as the server writes it in the refusal's detail.
  final String wire;

  /// The value a server reason names; [other] for one this build does not
  /// know.
  static StockRefusal fromWire(String reason) => _byWire[reason] ?? other;

  static final Map<String, StockRefusal> _byWire = {
    for (final r in values)
      if (r != other) r.wire: r,
  };
}
