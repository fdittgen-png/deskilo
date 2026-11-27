// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- ONE table of unit conversions, run against the domain's rule (`unitFactor`, lib/features/stock/domain/unit_conversions.dart) in
// test/parity/unit_convert_test.dart and against the server's `unit_convert` as pgTAP (supabase/tests/database/576_unit_convert.sql,
// whose rows are this table's rows to the letter: the parity test prints each row as SQL and finds it there). A conversion is
// DEFINED, never implied: one step, never chained; an item's own conversion first, then the business's general one; either way
// round at the inverse factor; no definition is no conversion.
//
// The world: a business with the thirteen built-in units, a drum (a length: 50 m) and two packaging units, a sack and a carton.
// Beans are counted in grams and come in sacks of 60000 g; coffee is counted in grams and its kilo is 900 g; mugs are counted in pieces
// and come in cartons of 12.
// An outcome is the quantity in the unit asked for, or `none` when no conversion is defined.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/unit_conversions.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

typedef UnitConvertCase = ({String id, String name, String item, String from, String to, String quantity, String outcome});

/// The units of the world: the built-ins, a drum of 50 m, and two packaging units.
final List<WorkspaceUnit> unitConvertUnits = [
  ...builtInUnits,
  const WorkspaceUnit(code: 'drum', label: 'Drum', dimension: UnitDimension.length, factorNum: 50, factorDen: 1),
  const WorkspaceUnit(code: 'sack', label: 'Sack', dimension: UnitDimension.package, factorNum: 1, factorDen: 1),
  const WorkspaceUnit(code: 'carton', label: 'Carton', dimension: UnitDimension.package, factorNum: 1, factorDen: 1),
];

/// An item of the world: its inventory unit and its own conversions.
typedef UnitConvertItem = ({String inventory, List<StockUnitDraft> units});

const Map<String, UnitConvertItem> unitConvertItems = {
  'BEANS': (inventory: 'g', units: [StockUnitDraft(unit: 'sack', factorNum: 60000, factorDen: 1)]),
  'COFFEE': (inventory: 'g', units: [StockUnitDraft(unit: 'kg', factorNum: 900, factorDen: 1)]),
  'MUGS': (inventory: 'piece', units: [StockUnitDraft(unit: 'carton', factorNum: 12, factorDen: 1)]),
};

const List<UnitConvertCase> unitConvertCases = [
  (id: 'c01', name: 'the same unit is itself', item: 'BEANS', from: 'g', to: 'g', quantity: '5', outcome: '5'),
  (id: 'c02', name: 'a general conversion', item: 'BEANS', from: 'kg', to: 'g', quantity: '2', outcome: '2000'),
  (id: 'c03', name: 'a general conversion the other way round', item: 'BEANS', from: 'g', to: 'kg', quantity: '1500', outcome: '1.5'),
  (id: 'c04', name: 'an item\'s own conversion', item: 'BEANS', from: 'sack', to: 'g', quantity: '2', outcome: '120000'),
  (id: 'c05', name: 'an item\'s own conversion the other way round', item: 'BEANS', from: 'g', to: 'sack', quantity: '120000', outcome: '2'),
  (id: 'c06', name: 'the item\'s own conversion wins over the general one', item: 'COFFEE', from: 'kg', to: 'g', quantity: '1', outcome: '900'),
  (id: 'c07', name: 'and the other way round', item: 'COFFEE', from: 'g', to: 'kg', quantity: '900', outcome: '1'),
  (id: 'c08', name: 'one step, never chained: a sack is grams, grams are kilos, a sack is not kilos', item: 'BEANS', from: 'sack', to: 'kg', quantity: '1', outcome: 'none'),
  (id: 'c09', name: 'no conversion by dimension: a litre is not grams', item: 'BEANS', from: 'l', to: 'g', quantity: '1', outcome: 'none'),
  (id: 'c10', name: 'a packaging unit the item does not list has no conversion', item: 'BEANS', from: 'carton', to: 'g', quantity: '1', outcome: 'none'),
  (id: 'c11', name: 'a packaging unit converts through the item\'s own factor', item: 'MUGS', from: 'carton', to: 'piece', quantity: '3', outcome: '36'),
  (id: 'c12', name: 'an item\'s conversion holds toward its own unit only', item: 'MUGS', from: 'carton', to: 'g', quantity: '1', outcome: 'none'),
  (id: 'c13', name: 'a unit the business made has its conversions', item: 'BEANS', from: 'm', to: 'drum', quantity: '100', outcome: '2'),
  (id: 'c14', name: 'and to the larger units', item: 'BEANS', from: 'km', to: 'drum', quantity: '1', outcome: '20'),
  (id: 'c15', name: 'a general conversion serves any item', item: 'MUGS', from: 'kg', to: 'g', quantity: '1', outcome: '1000'),
];

/// What the domain's rule answers for [c]: the quantity in the unit asked for, or `none`.
String runUnitConvertCase(UnitConvertCase c) {
  final item = unitConvertItems[c.item]!;
  final factor = unitFactor(
    from: c.from,
    to: c.to,
    inventoryUnit: item.inventory,
    itemUnits: item.units,
    general: linkedConversions(unitConvertUnits),
  );
  if (factor == null) return 'none';
  final converted = ExactQuantity.parse(c.quantity).scaled(factor.num, factor.den, round: true).value;
  return converted == null ? 'none' : _trimmed(converted.text);
}

/// 2.500000 is 2.5, 2.000000 is 2: the server's `trim_scale`.
String _trimmed(String text) {
  if (!text.contains('.')) return text;
  final cut = text.replaceFirst(RegExp(r'0+$'), '');
  return cut.endsWith('.') ? cut.substring(0, cut.length - 1) : cut;
}

/// The row as pgTAP states it (the parity test finds this text in the database file).
String unitConvertAsSql(UnitConvertCase c) =>
    "select is(pg_temp.conv('${c.item}', '${c.from}', '${c.to}', '${c.quantity}'), '${c.outcome}', '${c.id} ${c.name.replaceAll("'", "''")}');";
