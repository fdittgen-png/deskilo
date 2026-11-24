// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1) -- what the editors check before they ask: the cheap, local half
// of the server's rules, so a mistake is shown under its field at once. The
// server decides; a refusal it gives is shown under the same field.
import 'stock_config.dart';

/// The location kinds a person can create, from the broadest level to the narrowest. The
/// legacy `warehouse` is a site made before the levels: it is kept, not offered.
const List<String> stockPlaceKinds = ['site', 'zone', 'aisle', 'bay', 'shelf', 'bin'];

/// The level of a kind in the address (`site` 1 ... `shelf` and `bin` 5); null for a place
/// that is placed freely (a counter, a kitchen, a vehicle, a machine, a slot). The server's
/// `stock_location_kinds.level`.
int? stockKindLevel(String kind) => switch (kind) {
  'site' || 'warehouse' => 1,
  'zone' => 2,
  'aisle' => 3,
  'bay' => 4,
  'shelf' || 'bin' => 5,
  _ => null,
};

/// The places [kind] may sit directly under: those of the level above; none for a site, which
/// is a root. A place of no level may sit under any real place.
List<StockPlaceConfig> stockParentChoices(String kind, List<StockPlaceConfig> places) {
  final level = stockKindLevel(kind);
  return [
    for (final p in places)
      if (!p.virtual && (level == null || stockKindLevel(p.kind) == level - 1)) p,
  ];
}

/// Field keys as the server names them (`units[0].factor_den`).
String stockUnitField(int index, String part) => 'units[$index].$part';
String stockCodeField(int index, String part) => 'codes[$index].$part';

/// The mistakes in [units] and [codes] that need no server to see:
/// an empty or repeated unit, a factor that is not positive, a default taken
/// twice, an empty or repeated code, a code naming a unit the item lacks.
/// The map is keyed by the server's field name; the value is the server's
/// reason, so one text table serves both.
Map<String, StockRefusal> checkStockItem({
  required List<StockUnitDraft> units,
  required List<StockCodeDraft> codes,
}) {
  final errors = <String, StockRefusal>{};
  final seen = <String>{};
  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    if (u.unit.trim().isEmpty) {
      errors[stockUnitField(i, 'unit')] = StockRefusal.unitUnknown;
    } else if (!seen.add(u.unit.trim())) {
      errors[stockUnitField(i, 'unit')] = StockRefusal.unitDuplicate;
    }
    if (u.factorNum <= 0 || u.factorDen <= 0) {
      errors[stockUnitField(i, 'factor_den')] = StockRefusal.factorInvalid;
    }
  }
  if (units.where((u) => u.defaultPurchase).length > 1) {
    errors['units'] = StockRefusal.defaultPurchaseTwice;
  } else if (units.where((u) => u.defaultSale).length > 1) {
    errors['units'] = StockRefusal.defaultSaleTwice;
  }
  final codeSeen = <String>{};
  for (var i = 0; i < codes.length; i++) {
    final c = codes[i];
    if (c.code.trim().isEmpty) {
      errors[stockCodeField(i, 'code')] = StockRefusal.codeMalformed;
    } else if (!codeSeen.add(c.code.trim())) {
      errors[stockCodeField(i, 'code')] = StockRefusal.codeDuplicate;
    } else if (c.kind == 'gtin' && !RegExp(r'^[0-9]{8,14}$').hasMatch(c.code.trim())) {
      errors[stockCodeField(i, 'code')] = StockRefusal.gtinLength;
    }
    if (c.unit != null && !units.any((u) => u.unit.trim() == c.unit)) {
      errors[stockCodeField(i, 'unit')] = StockRefusal.unitUnknown;
    }
  }
  return errors;
}

/// The mistakes of a place that need no server to see.
Map<String, StockRefusal> checkStockPlace({
  required String code,
  required String name,
  required String barcode,
}) => {
  if (code.trim().isEmpty) 'code': StockRefusal.codeMalformed,
  if (name.trim().length > 80) 'name': StockRefusal.tooLong,
  if (barcode.trim().length > 64) 'barcode': StockRefusal.codeMalformed,
};

/// The mistakes in the variants of one item that need no server to see: a
/// variant with no value chosen, two with the same combination, a price
/// below zero. Keyed by the server's field name; the value is its reason.
Map<String, StockRefusal> checkStockVariants(List<({Map<String, String> values, int? priceCents})> variants) {
  final errors = <String, StockRefusal>{};
  final seen = <String>{};
  for (var i = 0; i < variants.length; i++) {
    final v = variants[i];
    if (v.values.isEmpty) {
      errors['variants[$i].values'] = StockRefusal.variantValuesMissing;
      continue;
    }
    final canonical = (v.values.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => '${e.key}:${e.value}')
        .join(',');
    if (!seen.add(canonical)) errors['variants[$i].values'] = StockRefusal.variantCombinationDuplicate;
    if ((v.priceCents ?? 0) < 0) errors['variants[$i].price_cents'] = StockRefusal.priceInvalid;
  }
  return errors;
}

/// #4403 -- what the server refuses of a place beyond its own fields: a code taken among its siblings (0836:499,
/// 0855:140-145), a parent that is the place itself (0836:507), a level under the wrong level or under none, checked
/// when the place is made or its kind or parent changes (0855:155-166), and a use that is not picking or reserve
/// (0855:133). [places] are the business's, by id; [old] is the place as it was (none for a new one). Null: none.
StockConfigRefused? stockPlaceSaveRefusal(
  Map<String, StockPlaceConfig> places, {
  required String code,
  required String kind,
  required String? parentId,
  required String? pickRole,
  StockPlaceConfig? old,
}) {
  final placeId = old?.id;
  if (places.values.any((p) => p.code == code && p.parentId == parentId && p.id != placeId)) {
    return const StockConfigRefused('code', StockRefusal.codeDuplicate);
  }
  if (parentId != null && parentId == placeId) return const StockConfigRefused('parent_id', StockRefusal.locationCycle);
  final level = stockKindLevel(kind);
  if (level != null && (old == null || kind != old.kind || parentId != old.parentId)) {
    if (parentId == null) {
      if (level != 1) return const StockConfigRefused('parent_id', StockRefusal.levelParentMissing);
    } else if (stockKindLevel(places[parentId]?.kind ?? '') != level - 1) {
      return const StockConfigRefused('parent_id', StockRefusal.levelParentWrong);
    }
  }
  if (pickRole != null && pickRole != 'picking' && pickRole != 'reserve') {
    return const StockConfigRefused('pick_role', StockRefusal.pickRoleUnknown);
  }
  return null;
}

/// The address of a place under [parentId]: its parent's address, then its own [code] (0855, the address trigger).
String stockAddressUnder(Map<String, StockPlaceConfig> places, String? parentId, String code) =>
    parentId == null ? code : '${places[parentId]?.addressPath ?? ''}$stockAddressJoint$code';

/// Everything below [parentId] in [places] takes the address of its parent again, as the server's trigger does.
void stockReaddressBelow(Map<String, StockPlaceConfig> places, String parentId) {
  for (final c in places.values.where((p) => p.parentId == parentId).toList()) {
    places[c.id] = StockPlaceConfig(
      id: c.id, revision: c.revision, kind: c.kind, code: c.code, name: c.name, barcode: c.barcode,
      parentId: c.parentId, active: c.active, virtual: c.virtual,
      receivesFromSuppliers: c.receivesFromSuppliers, pickRole: c.pickRole,
      addressPath: stockAddressUnder(places, c.parentId, c.code),
    );
    stockReaddressBelow(places, c.id);
  }
}

/// #4403 -- what the server refuses of a dimension (0837:469-492): a name of 1 to 60 characters, not taken by
/// another dimension of the business, and value labels that are not empty and not repeated. [others] are the names
/// of the business's other dimensions. Null: none.
StockConfigRefused? stockDimensionRefusal(String name, Iterable<String> others, List<String> labels) {
  if (name.isEmpty || name.length > 60) return const StockConfigRefused('name', StockRefusal.nameMalformed);
  if (others.contains(name)) return const StockConfigRefused('name', StockRefusal.nameDuplicate);
  final seen = <String>{};
  for (var i = 0; i < labels.length; i++) {
    final label = labels[i].trim();
    if (label.isEmpty) return StockConfigRefused('values[$i].label', StockRefusal.nameMalformed);
    if (!seen.add(label)) return StockConfigRefused('values[$i].label', StockRefusal.nameDuplicate);
  }
  return null;
}

/// #4403 -- the first refusal of the server for the variants of one item, in its order (0837:579-595): values
/// chosen, a price not below zero, each value one of a dimension of the business, a combination not repeated.
/// [valuesOf] answers the value ids of a dimension (null for one the business does not have). Null: none.
StockConfigRefused? stockVariantsRefusal(
  List<({Map<String, String> values, int? priceCents})> variants,
  Set<String>? Function(String dimensionId) valuesOf,
) {
  final seen = <String>{};
  for (var i = 0; i < variants.length; i++) {
    final v = variants[i];
    if (v.values.isEmpty) return StockConfigRefused('variants[$i].values', StockRefusal.variantValuesMissing);
    if ((v.priceCents ?? 0) < 0) return StockConfigRefused('variants[$i].price_cents', StockRefusal.priceInvalid);
    if (v.values.entries.any((e) => valuesOf(e.key)?.contains(e.value) != true)) {
      return StockConfigRefused('variants[$i].values', StockRefusal.valueForeign);
    }
    final canonical = (v.values.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}:${e.value}').join(',');
    if (!seen.add(canonical)) return StockConfigRefused('variants[$i].values', StockRefusal.variantCombinationDuplicate);
  }
  return null;
}

/// #4403 -- what the server refuses of a supplier's article, in its order (0837:723-738): a supplier of the
/// business, an item of it, a reference of 1 to 80 characters, a purchase unit the item lists, and a reference the
/// supplier does not already use. Null: none.
StockConfigRefused? supplierMappingRefusal({
  required bool supplierKnown,
  required StockItemConfig? item,
  required String articleRef,
  required String? purchaseUnit,
  required bool refTaken,
}) {
  if (!supplierKnown) return const StockConfigRefused('supplier_id', StockRefusal.supplierForeign);
  if (item == null) return const StockConfigRefused('item_id', StockRefusal.itemForeign);
  if (articleRef.isEmpty || articleRef.length > 80) return const StockConfigRefused('article_ref', StockRefusal.codeMalformed);
  if (purchaseUnit != null && !item.units.any((u) => u.unit == purchaseUnit)) {
    return const StockConfigRefused('purchase_unit', StockRefusal.unitNotOfItem);
  }
  if (refTaken) return const StockConfigRefused('article_ref', StockRefusal.mappingDuplicate);
  return null;
}
