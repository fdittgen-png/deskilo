// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- a conversion is DEFINED, never implied. The business's GENERAL conversions (1 kg = 1000 g, `unit_conversions`, 0968) are
// master data a person edits in Settings; an item's own conversion (a carton of 12) is its factor to its inventory unit. THE rule,
// written once for the server (`unit_factor`) and once here, and held equal by one table of cases (test/parity/unit_convert_cases.dart):
// one step, never chained; the item's own conversion first, then the general one; either way round at the inverse factor; the same
// unit is 1/1; no definition is no conversion.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'stock_config.dart';
import 'workspace_units.dart';

/// One general conversion: 1 [fromUnit] is [factorNum] / [factorDen] [toUnit].
class UnitConversion {
  const UnitConversion({required this.fromUnit, required this.toUnit, required this.factorNum, required this.factorDen});

  /// Reads a row of `unit_conversions` or the answer of `unit_conversion_save_v1`.
  factory UnitConversion.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'unit_conversions');
    return UnitConversion(
      fromUnit: r.string('from_unit'),
      toUnit: r.string('to_unit'),
      factorNum: r.integer('factor_num'),
      factorDen: r.integer('factor_den'),
    );
  }

  final String fromUnit;
  final String toUnit;
  final int factorNum;
  final int factorDen;

  /// Whether this conversion is between [a] and [b], whichever way round it is written.
  bool joins(String a, String b) => (fromUnit == a && toUnit == b) || (fromUnit == b && toUnit == a);

  @override
  bool operator ==(Object other) =>
      other is UnitConversion && other.fromUnit == fromUnit && other.toUnit == toUnit && other.factorNum == factorNum && other.factorDen == factorDen;

  @override
  int get hashCode => Object.hash(fromUnit, toUnit, factorNum, factorDen);
}

/// The general conversions of a business, behind one port (the server's, or the Demo's).
abstract interface class UnitConversions {
  Future<List<UnitConversion>> conversions(String workspaceId);

  /// Defines the conversion between two units (`unit_conversion_save_v1`), replacing the one that was, either way round; a retried
  /// [requestId] answers once.
  Future<UnitConversion> save(String workspaceId, {required String requestId, required UnitConversion conversion});

  /// Takes the conversion between two units away (`unit_conversion_delete_v1`).
  Future<void> delete(String workspaceId, {required String requestId, required String fromUnit, required String toUnit});
}

/// The one step from [from] to [to] as a fraction (1 [from] = num / den [to]), or null when none is defined. [inventoryUnit] is the
/// item's own unit and [itemUnits] its own conversions (its unit and its factor to the inventory unit); [general] are the
/// business's. The same rule as `unit_factor` (0968).
({int num, int den})? unitFactor({
  required String? from,
  required String to,
  String? inventoryUnit,
  List<StockUnitDraft> itemUnits = const [],
  required Iterable<UnitConversion> general,
}) {
  if (from == null || from == to) return (num: 1, den: 1);
  return _itemStep(from, to, inventoryUnit, itemUnits) ?? _generalStep(from, to, general);
}

/// The item's own conversion between its unit and its inventory unit, either way round.
({int num, int den})? _itemStep(String from, String to, String? inventoryUnit, List<StockUnitDraft> itemUnits) {
  for (final u in itemUnits) {
    if (inventoryUnit == null) break;
    if (to == inventoryUnit && u.unit == from) return (num: u.factorNum, den: u.factorDen);
    if (from == inventoryUnit && u.unit == to) return (num: u.factorDen, den: u.factorNum);
  }
  return null;
}

/// The business's general conversion of the pair, written either way round.
({int num, int den})? _generalStep(String from, String to, Iterable<UnitConversion> general) {
  for (final c in general) {
    if (c.fromUnit == from && c.toUnit == to) return (num: c.factorNum, den: c.factorDen);
    if (c.fromUnit == to && c.toUnit == from) return (num: c.factorDen, den: c.factorNum);
  }
  return null;
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// The conversions between the units of one dimension that a business starts with, and gives each unit it makes (`unit_conversions_link`
/// of 0968): the larger unit converts to the smaller, equal ones by code, a packaging unit to none.
List<UnitConversion> linkedConversions(Iterable<WorkspaceUnit> units) {
  final all = units.where((u) => u.dimension != UnitDimension.package).toList();
  final out = <UnitConversion>[];
  for (final a in all) {
    for (final b in all) {
      if (a.code == b.code || a.dimension != b.dimension) continue;
      final left = a.factorNum * b.factorDen;
      final right = a.factorDen * b.factorNum;
      if (left > right || (left == right && a.code.compareTo(b.code) < 0)) {
        final g = _gcd(left, right);
        out.add(UnitConversion(fromUnit: a.code, toUnit: b.code, factorNum: left ~/ g, factorDen: right ~/ g));
      }
    }
  }
  return out;
}

/// What the built-in units convert between: the rows a business has before it changes anything.
final List<UnitConversion> builtInConversions = linkedConversions(builtInUnits);

/// A conversion's factor as the person reads it: a decimal (`1000`, `0.001`) when six decimals hold it, else the fraction (`1/3`).
String conversionFactorText(UnitConversion c) =>
    factorText(WorkspaceUnit(code: c.fromUnit, dimension: UnitDimension.count, factorNum: c.factorNum, factorDen: c.factorDen));

/// The codes of [units] an item counted in [inventoryUnit] can be ordered, received or sold in: its own unit, the units of its own
/// conversions, and every unit with a general conversion to its unit (one step, either way). A packaging unit it does not list is not
/// among them. The same answer as the server's `unit_is_convertible` (0971).
List<String> convertibleUnitCodes({
  required String inventoryUnit,
  required List<StockUnitDraft> itemUnits,
  required Iterable<WorkspaceUnit> units,
  required Iterable<UnitConversion> general,
}) => [
  for (final u in units)
    if (!u.archived &&
        (u.code == inventoryUnit ||
            unitFactor(from: u.code, to: inventoryUnit, inventoryUnit: inventoryUnit, itemUnits: itemUnits, general: general) != null))
      u.code,
];

/// #4479 -- the price of ONE [unit] of an item whose price per inventory unit is [itemPriceCents] (VAT-inclusive, as the item's is): the
/// item's price for its inventory unit (or no unit), the price a unit carries of its own, else the item's price times what one of the unit
/// makes of the inventory unit, rounded half up once. Null when no conversion is defined (the server's DKG02: never read as one).
/// The same rule as `item_unit_price` (0974).
int? unitPriceCents({
  required int itemPriceCents,
  required String? unit,
  required String inventoryUnit,
  required List<StockUnitDraft> itemUnits,
  required Iterable<UnitConversion> general,
}) {
  if (unit == null || unit.isEmpty || unit == inventoryUnit) return itemPriceCents;
  for (final u in itemUnits) {
    if (u.unit == unit && u.priceCents != null) return u.priceCents;
  }
  final f = unitFactor(from: unit, to: inventoryUnit, inventoryUnit: inventoryUnit, itemUnits: itemUnits, general: general);
  if (f == null) return null;
  // round half up on a non-negative price: (2 * p * num + den) ~/ (2 * den)
  return (2 * itemPriceCents * f.num + f.den) ~/ (2 * f.den);
}
