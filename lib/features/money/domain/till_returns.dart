// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4478 -- a deposit brought back, on the basket: a returned line of its own (never merged into a sale of the same
// item), more of it when it is brought back again.
import 'counter_till.dart';
import 'till_quantity.dart';

/// [lines] with [quantity] (an exact quantity) of the deposit [itemId] brought back; null when the sum is not one.
List<TillLine>? tillLinesWithReturn(List<TillLine> lines, {required String itemId, required String name, required String unit, required String quantity}) {
  final out = [...lines];
  final at = out.indexWhere((l) => l.itemId == itemId && l.returned);
  if (at < 0) return out..add(TillLine(itemId: itemId, name: name, quantity: quantity, unit: unit, returned: true));
  final more = tillQuantitySum(out[at].quantity, quantity);
  if (more == null) return null;
  return out..[at] = out[at].withQuantity(more);
}
