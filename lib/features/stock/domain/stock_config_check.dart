// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1) -- what the editors check before they ask: the cheap, local half
// of the server's rules, so a mistake is shown under its field at once. The
// server decides; a refusal it gives is shown under the same field.
import 'stock_config.dart';

/// The location kinds a person can create (the server's non-virtual ones).
const List<String> stockPlaceKinds = ['warehouse', 'zone', 'shelf', 'bin'];

/// Field keys as the server names them (`units[0].factor_den`).
String stockUnitField(int index, String part) => 'units[$index].$part';
String stockCodeField(int index, String part) => 'codes[$index].$part';

/// The mistakes in [units] and [codes] that need no server to see:
/// an empty or repeated unit, a factor that is not positive, a default taken
/// twice, an empty or repeated code, a code naming a unit the item lacks.
/// The map is keyed by the server's field name; the value is the server's
/// reason, so one text table serves both.
Map<String, String> checkStockItem({
  required List<StockUnitDraft> units,
  required List<StockCodeDraft> codes,
}) {
  final errors = <String, String>{};
  final seen = <String>{};
  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    if (u.unit.trim().isEmpty) {
      errors[stockUnitField(i, 'unit')] = 'unit_unknown';
    } else if (!seen.add(u.unit.trim())) {
      errors[stockUnitField(i, 'unit')] = 'unit_duplicate';
    }
    if (u.factorNum <= 0 || u.factorDen <= 0) {
      errors[stockUnitField(i, 'factor_den')] = 'factor_invalid';
    }
  }
  if (units.where((u) => u.defaultPurchase).length > 1) {
    errors['units'] = 'default_purchase_twice';
  } else if (units.where((u) => u.defaultSale).length > 1) {
    errors['units'] = 'default_sale_twice';
  }
  final codeSeen = <String>{};
  for (var i = 0; i < codes.length; i++) {
    final c = codes[i];
    if (c.code.trim().isEmpty) {
      errors[stockCodeField(i, 'code')] = 'code_malformed';
    } else if (!codeSeen.add(c.code.trim())) {
      errors[stockCodeField(i, 'code')] = 'code_duplicate';
    } else if (c.kind == 'gtin' && !RegExp(r'^[0-9]{8,14}$').hasMatch(c.code.trim())) {
      errors[stockCodeField(i, 'code')] = 'gtin_length';
    }
    if (c.unit != null && !units.any((u) => u.unit.trim() == c.unit)) {
      errors[stockCodeField(i, 'unit')] = 'unit_unknown';
    }
  }
  return errors;
}

/// The mistakes of a place that need no server to see.
Map<String, String> checkStockPlace({
  required String code,
  required String name,
  required String barcode,
}) => {
  if (code.trim().isEmpty) 'code': 'code_malformed',
  if (name.trim().length > 80) 'name': 'too_long',
  if (barcode.trim().length > 64) 'barcode': 'code_malformed',
};

/// The mistakes in the variants of one item that need no server to see: a
/// variant with no value chosen, two with the same combination, a price
/// below zero. Keyed by the server's field name; the value is its reason.
Map<String, String> checkStockVariants(List<({Map<String, String> values, int? priceCents})> variants) {
  final errors = <String, String>{};
  final seen = <String>{};
  for (var i = 0; i < variants.length; i++) {
    final v = variants[i];
    if (v.values.isEmpty) {
      errors['variants[$i].values'] = 'variant_values_missing';
      continue;
    }
    final canonical = (v.values.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => '${e.key}:${e.value}')
        .join(',');
    if (!seen.add(canonical)) errors['variants[$i].values'] = 'variant_combination_duplicate';
    if ((v.priceCents ?? 0) < 0) errors['variants[$i].price_cents'] = 'price_invalid';
  }
  return errors;
}
