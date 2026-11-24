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
