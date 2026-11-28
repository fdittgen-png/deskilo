// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- what a line of an item starts from when its group sells or buys it in a unit: the item's own default first, else the group's; the
// group's unit counts among the item's with the group's factor (unless the item lists the unit itself), and the group's sale price is the
// price of its sale unit unless the item has a price of its own for it. The same rule as the server's `unit_factor` and `item_unit_price` (0992).
import 'package:deskilo/features/stock/domain/group_unit_defaults.dart';
import 'package:deskilo/features/stock/domain/item_groups.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:flutter_test/flutter_test.dart';

EffectiveParam _from(Object? value) => EffectiveParam(value: value, source: 'group', group: 'Mugs');

ItemEffective _effective(Map<String, Object?> values) => ItemEffective(
  itemId: 'i',
  groupId: 'g',
  params: {for (final e in values.entries) e.key: _from(e.value)},
  problems: const [],
);

final _group = GroupUnitDefaults.of(
  _effective({
    groupParamSaleUnit: 'carton',
    groupParamSaleFactorNum: 12,
    groupParamSaleFactorDen: 1,
    groupParamSalePrice: 1100,
    groupParamPurchaseUnit: 'pallet',
    groupParamPurchaseFactorNum: 480,
    groupParamPurchaseFactorDen: 1,
  }),
);

void main() {
  test('the group\'s units count among the item\'s, with the group\'s factors, unless the item lists them itself', () {
    expect([for (final u in _group.unitsWith(const [])) (u.unit, u.factorNum, u.factorDen)], [('carton', 12, 1), ('pallet', 480, 1)]);
    const listed = StockUnitDraft(unit: 'carton', factorNum: 10, factorDen: 1);
    expect([for (final u in _group.unitsWith(const [listed])) (u.unit, u.factorNum)], [('carton', 10), ('pallet', 480)], reason: 'the item\'s own factor wins');
  });

  test('a line starts in the item\'s own default unit, else the group\'s', () {
    expect((_group.saleStart(const []), _group.purchaseStart(const [])), ('carton', 'pallet'));
    const own = StockUnitDraft(unit: 'piece', factorNum: 1, factorDen: 1, defaultSale: true, defaultPurchase: true);
    expect((_group.saleStart(const [own]), _group.purchaseStart(const [own])), ('piece', 'piece'));
  });

  test('the group\'s price is the price of its sale unit unless the item has one of its own for it', () {
    expect(_group.priceOf('carton', const []), 1100);
    expect(_group.priceOf('pallet', const []), isNull);
    const priced = StockUnitDraft(unit: 'carton', factorNum: 12, factorDen: 1, priceCents: 1050);
    expect(_group.priceOf('carton', const [priced]), isNull);
  });

  test('an item with no group, or whose group says nothing, starts from nothing', () {
    expect(GroupUnitDefaults.of(null).saleStart(const []), isNull);
    expect(GroupUnitDefaults.none.unitsWith(const []), isEmpty);
  });
}
