// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4471 -- the units a form of the money feature offers to PICK from for [workspaceId]: the business's units of measure that are
// not archived while the units feature is on, the six of before while it is off. The composition root (lib/app) wires them
// behind it (the money feature never imports the stock); with nothing wired none is offered.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/line_unit.dart';

final pickableUnitsProvider = Provider.family<List<LineUnit>, String>((ref, workspaceId) => const <LineUnit>[]);

/// One item of one business, ordered from [supplierId] (null: no supplier chosen yet).
typedef _ItemUnitsKey = ({String workspaceId, String itemId, String? supplierId});

/// #4479 -- what an order line of a stocked item offers: the units it converts from, and the one a new line starts in (the supplier's own
/// purchase unit for the item, else the item's default purchase unit, else its inventory unit).
class ItemOrderUnits {
  const ItemOrderUnits({required this.units, this.defaultUnit, this.saleUnit});

  final List<LineUnit> units;
  final String? defaultUnit;

  /// #4479 -- the unit a line that SELLS the item starts in: its default sale unit, else its inventory unit.
  final String? saleUnit;
}

/// #4479 -- the units an order line of a STOCKED item may be in and the one it starts in. Null when the item is not restricted (not stocked,
/// or nothing wired): the business's units then. The composition root wires it (the money feature never imports the stock).
final itemOrderUnitsProvider = FutureProvider.autoDispose.family<ItemOrderUnits?, _ItemUnitsKey>((ref, key) async => null);

/// One unit of one item of one business.
typedef _ItemUnitKey = ({String workspaceId, String itemId, String unit});

/// #4479 -- the price of ONE [unit] of an item, in minor units (its own price, else the item's price times its factor), or null when none is
/// defined. The composition root wires it from the stock's rule (`unitPriceCents`); with nothing wired no price is offered.
final itemUnitPriceProvider = FutureProvider.autoDispose.family<int?, _ItemUnitKey>((ref, key) async => null);
