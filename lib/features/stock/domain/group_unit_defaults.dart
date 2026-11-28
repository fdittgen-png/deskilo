// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- what an item reads of its group's units, for the forms that start a line: the unit it is SOLD in (with its factor to the inventory
// unit and its price) and the unit it is BOUGHT in (with its factor), each as it is in force for the item (its own, else its sub-group's,
// else its group's). The rules that convert and price (`unit_factor`, `item_unit_price`, 0992) read the same values on the server, so a line in
// one of these units is accepted there. Pure: the answer of `item_effective_settings_v1` goes in, the starting unit and the units to add to the
// item's own come out.
import 'item_groups.dart';
import 'stock_config.dart';

class GroupUnitDefaults {
  const GroupUnitDefaults({this.saleUnit, this.saleFactor, this.salePriceCents, this.purchaseUnit, this.purchaseFactor});

  /// Nothing is read: no group, groups off, or the item could not be read.
  static const none = GroupUnitDefaults();

  factory GroupUnitDefaults.of(ItemEffective? effective) {
    Object? value(String p) => effective?.params[p]?.value;
    ({int num, int den})? factor(String numKey, String denKey) =>
        value(numKey) is num ? (num: (value(numKey)! as num).toInt(), den: ((value(denKey) ?? 1) as num).toInt()) : null;
    final sale = value(groupParamSaleUnit);
    final purchase = value(groupParamPurchaseUnit);
    return GroupUnitDefaults(
      saleUnit: sale is String && sale.isNotEmpty ? sale : null,
      saleFactor: factor(groupParamSaleFactorNum, groupParamSaleFactorDen),
      salePriceCents: value(groupParamSalePrice) is num ? (value(groupParamSalePrice)! as num).toInt() : null,
      purchaseUnit: purchase is String && purchase.isNotEmpty ? purchase : null,
      purchaseFactor: factor(groupParamPurchaseFactorNum, groupParamPurchaseFactorDen),
    );
  }

  final String? saleUnit;
  final ({int num, int den})? saleFactor;
  final int? salePriceCents;
  final String? purchaseUnit;
  final ({int num, int den})? purchaseFactor;

  /// The units the item converts from, [own] and those its group sells or buys it in (a unit it lists itself is its own: its factor and price
  /// are the item's, as on the server).
  List<StockUnitDraft> unitsWith(List<StockUnitDraft> own) => [
    ...own,
    if (saleUnit != null && saleFactor != null && !own.any((u) => u.unit == saleUnit))
      StockUnitDraft(unit: saleUnit!, factorNum: saleFactor!.num, factorDen: saleFactor!.den),
    if (purchaseUnit != null && purchaseFactor != null && purchaseUnit != saleUnit && !own.any((u) => u.unit == purchaseUnit))
      StockUnitDraft(unit: purchaseUnit!, factorNum: purchaseFactor!.num, factorDen: purchaseFactor!.den),
  ];

  /// The unit a line that BUYS the item starts in: the item's own default purchase unit, else its group's.
  String? purchaseStart(List<StockUnitDraft> own) => own.where((u) => u.defaultPurchase).map((u) => u.unit).firstOrNull ?? purchaseUnit;

  /// The unit a line that SELLS the item starts in: the item's own default sale unit, else its group's.
  String? saleStart(List<StockUnitDraft> own) => own.where((u) => u.defaultSale).map((u) => u.unit).firstOrNull ?? saleUnit;

  /// The price of one [unit] the group states: the price of its sale unit, unless the item lists that unit with a price of its own.
  int? priceOf(String? unit, List<StockUnitDraft> own) =>
      unit != null && unit == saleUnit && !own.any((u) => u.unit == unit && u.priceCents != null) ? salePriceCents : null;
}
