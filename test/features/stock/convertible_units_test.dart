// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- the units an item can be ordered, received or sold in: its own, its own conversions' and the business's general ones,
// one step. The same answer as the server's `unit_is_convertible` (0971, pgTAP 578): mugs counted in pieces come in cartons of 12, a
// kilo of them has no conversion, plates that list no carton are not offered one.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/unit_conversions.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const carton = WorkspaceUnit(code: 'carton', label: 'Carton', dimension: UnitDimension.package, factorNum: 1, factorDen: 1);
  final units = [...builtInUnits, carton];
  List<String> codes(String inventory, [List<StockUnitDraft> own = const []]) =>
      convertibleUnitCodes(inventoryUnit: inventory, itemUnits: own, units: units, general: builtInConversions);

  test('an item counted in pieces: its own unit and the cartons it lists, not a kilo', () {
    final own = [const StockUnitDraft(unit: 'carton', factorNum: 12, factorDen: 1)];
    expect(codes('piece', own), containsAll(['piece', 'carton']));
    expect(codes('piece', own), isNot(contains('kg')));
  });

  test('a carton it does not list is not offered', () {
    expect(codes('piece'), ['piece']);
  });

  test('a weight converts through the business\'s general conversions, one step either way', () {
    expect(codes('g'), containsAll(['g', 'kg']));
    expect(codes('kg'), containsAll(['kg', 'g']));
    expect(codes('g'), isNot(contains('l')));
  });

  test('an archived unit is not offered', () {
    final out = convertibleUnitCodes(
      inventoryUnit: 'g',
      itemUnits: const [],
      units: [...builtInUnits.where((u) => u.code != 'kg'), builtInUnits.firstWhere((u) => u.code == 'kg').copyWith(archived: true)],
      general: builtInConversions,
    );
    expect(out, isNot(contains('kg')));
  });
}
