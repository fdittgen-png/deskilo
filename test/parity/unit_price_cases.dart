// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- ONE table of what an item costs in one of its units, run against the domain's rule (`unitPriceCents`,
// lib/features/stock/domain/unit_conversions.dart) in test/parity/unit_price_test.dart and against the server's `item_unit_price` as pgTAP
// (supabase/tests/database/581_item_unit_price.sql, whose rows are this table's rows to the letter: the parity test prints each as SQL and
// finds it there). The inventory unit (or no unit) is the item's price; a unit with a price of its own is that price; else the item's price
// times what one of the unit makes of the inventory unit, rounded half up once; no conversion is `none` (DKG02), never one.
//
// The world: mugs cost 1,00 a piece and come in cartons of 12 priced 11,00 and boxes of 6 with no price of their own; beans cost 0,03 a
// gram; a litre of milk costs 0,95 (0,5 l bottles are not modelled).
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/unit_conversions.dart';

typedef UnitPriceCase = ({String id, String name, String item, String unit, String outcome});

typedef UnitPriceItem = ({int price, String inventory, List<StockUnitDraft> units});

const Map<String, UnitPriceItem> unitPriceItems = {
  'MUGS': (
    price: 100,
    inventory: 'piece',
    units: [
      StockUnitDraft(unit: 'carton', factorNum: 12, factorDen: 1, priceCents: 1100),
      StockUnitDraft(unit: 'box', factorNum: 6, factorDen: 1),
    ],
  ),
  'BEANS': (price: 3, inventory: 'g', units: []),
  'THIRDS': (price: 100, inventory: 'l', units: [StockUnitDraft(unit: 'third', factorNum: 1, factorDen: 3)]),
};

const List<UnitPriceCase> unitPriceCases = [
  (id: 'p01', name: 'the inventory unit is the item\'s price', item: 'MUGS', unit: 'piece', outcome: '100'),
  (id: 'p02', name: 'no unit is the item\'s price', item: 'MUGS', unit: '', outcome: '100'),
  (id: 'p03', name: 'a unit with a price of its own is that price, not twelve of the item', item: 'MUGS', unit: 'carton', outcome: '1100'),
  (id: 'p04', name: 'a unit with no price is the item\'s price times its factor', item: 'MUGS', unit: 'box', outcome: '600'),
  (id: 'p05', name: 'a general conversion prices the kilo of beans', item: 'BEANS', unit: 'kg', outcome: '3000'),
  (id: 'p06', name: 'a third of a litre, 33,33 rounded half up once', item: 'THIRDS', unit: 'third', outcome: '33'),
  (id: 'p07', name: 'no conversion, no price: a litre of beans', item: 'BEANS', unit: 'l', outcome: 'none'),
  (id: 'p08', name: 'a packaging unit the item does not list has none', item: 'BEANS', unit: 'carton', outcome: 'none'),
];

/// What the domain's rule answers for [c]: the price in minor units, or `none`.
String runUnitPriceCase(UnitPriceCase c) {
  final item = unitPriceItems[c.item]!;
  final price = unitPriceCents(
    itemPriceCents: item.price,
    unit: c.unit,
    inventoryUnit: item.inventory,
    itemUnits: item.units,
    general: builtInConversions,
  );
  return price == null ? 'none' : '$price';
}

/// The row as pgTAP states it (the parity test finds this text in the database file).
String unitPriceAsSql(UnitPriceCase c) =>
    "select is(pg_temp.price('${c.item}', '${c.unit}'), '${c.outcome}', '${c.id} ${c.name.replaceAll("'", "''")}');";
