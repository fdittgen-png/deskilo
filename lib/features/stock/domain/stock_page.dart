// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (A1) -- what the stock reads return: rows with exact quantities, and
// the continuation that says whether anything follows. Quantities are read
// from the server's text (never a JSON number) into `ExactQuantity`; an
// unknown valuation stays unknown (null), never zero.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// A position in a walk, as the server wrote it: sent back unchanged.
typedef StockCursor = Map<String, Object?>;

/// A bounded page: [rows], [complete] when nothing follows, else [next].
class StockPage<T> {
  const StockPage({required this.rows, required this.complete, this.next});

  final List<T> rows;
  final bool complete;
  final StockCursor? next;
}

/// One quantity of one item, in one lot (or none), at one real place.
class StockOnHandRow {
  const StockOnHandRow({
    required this.workspaceId,
    required this.itemId,
    required this.itemName,
    required this.lotId,
    required this.lotCode,
    required this.locationId,
    required this.locationCode,
    required this.locationName,
    required this.quantity,
    required this.unit,
    this.variantId,
    this.variantLabel,
  });

  final String workspaceId;
  final String itemId;
  final String itemName;
  final String? lotId;
  final String? lotCode;
  final String locationId;
  final String locationCode;
  final String locationName;

  /// #4169 -- the variant this stock is of (`Colour: Red · Size: M`), or none.
  final String? variantId;
  final String? variantLabel;

  /// The item with its variant, as a person reads it.
  String get itemLabel => variantLabel == null ? itemName : '$itemName · $variantLabel';

  /// A place as a person reads it: its code, and its name when it has one.
  String get locationLabel =>
      locationName.isEmpty ? locationCode : '$locationCode · $locationName';

  /// What is stored, in the item's inventory [unit].
  final ExactQuantity quantity;
  final String unit;

  factory StockOnHandRow.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_on_hand_page_v1');
    return StockOnHandRow(
      workspaceId: r.string('workspace_id'),
      itemId: r.string('item_id'),
      itemName: r.stringOr('item_name'),
      lotId: r.stringOrNull('lot_id'),
      lotCode: r.stringOrNull('lot_code'),
      locationId: r.string('location_id'),
      locationCode: r.string('location_code'),
      locationName: r.stringOr('location_name'),
      quantity: ExactQuantity.parse(r.string('quantity')),
      unit: r.string('unit'),
      variantId: r.stringOrNull('variant_id'),
      variantLabel: r.stringOrNull('variant_label'),
    );
  }
}

/// One movement: [quantity] in the inventory [unit], beside what was
/// entered, with what caused it.
class StockMovementRow {
  const StockMovementRow({
    required this.workspaceId,
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.lotId,
    required this.lotCode,
    required this.fromLocationId,
    required this.fromLocationCode,
    required this.toLocationId,
    required this.toLocationCode,
    required this.quantity,
    required this.unit,
    required this.enteredQuantity,
    required this.enteredUnit,
    required this.occurredAt,
    required this.reason,
    required this.unitCost,
    required this.causes,
    this.variantId,
    this.variantLabel,
  });

  final String workspaceId;
  final String id;
  final String itemId;
  final String itemName;
  final String? lotId;
  final String? lotCode;
  final String fromLocationId;
  final String fromLocationCode;
  final String toLocationId;
  final String toLocationCode;
  final ExactQuantity quantity;
  final String unit;
  final ExactQuantity enteredQuantity;
  final String enteredUnit;
  final DateTime occurredAt;
  final String reason;

  /// #4169 -- the variant that moved, or none.
  final String? variantId;
  final String? variantLabel;

  /// The item with its variant, as a person reads it.
  String get itemLabel => variantLabel == null ? itemName : '$itemName · $variantLabel';

  /// Minor units per inventory unit, frozen; null when the cost is unknown.
  final String? unitCost;

  /// What caused it, by kind (`receipt_line`, `purchase_line`, `event`,
  /// `invoice`): only the causes it has.
  final Map<String, String> causes;

  factory StockMovementRow.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_movements_page_v1');
    return StockMovementRow(
      workspaceId: r.string('workspace_id'),
      id: r.string('id'),
      itemId: r.string('item_id'),
      itemName: r.stringOr('item_name'),
      lotId: r.stringOrNull('lot_id'),
      lotCode: r.stringOrNull('lot_code'),
      fromLocationId: r.string('from_location_id'),
      fromLocationCode: r.string('from_location_code'),
      toLocationId: r.string('to_location_id'),
      toLocationCode: r.string('to_location_code'),
      quantity: ExactQuantity.parse(r.string('quantity')),
      unit: r.string('unit'),
      enteredQuantity: ExactQuantity.parse(r.string('entered_quantity')),
      enteredUnit: r.string('entered_unit'),
      occurredAt: r.dateTime('occurred_at'),
      reason: r.string('reason'),
      unitCost: r.stringOrNull('unit_cost'),
      variantId: r.stringOrNull('variant_id'),
      variantLabel: r.stringOrNull('variant_label'),
      causes: {
        for (final (key, column) in const [
          ('receipt_line', 'receipt_line_id'),
          ('purchase_line', 'purchase_line_id'),
          ('event', 'event_id'),
          ('invoice', 'invoice_id'),
        ])
          key: ?r.stringOrNull(column),
      },
    );
  }
}

/// A place of the business a filter can name: a shelf, a counter, a supplier.
class StockPlace {
  const StockPlace({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  /// What a person reads: the name when there is one, else the code.
  String get label => name.isEmpty ? code : '$code · $name';

  factory StockPlace.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_locations');
    return StockPlace(
      id: r.string('id'),
      code: r.string('code'),
      name: r.stringOr('name'),
    );
  }
}

/// A stock item a filter can name.
class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.unit,
    this.active = true,
    this.tillCategory,
    this.quickKeyColour,
    this.minAge,
    this.soldByWeight = false,
    this.depositItemId,
  });

  final String id;
  final String name;
  final String unit;

  /// Whether the item is on sale: a turned-off item stays in the stock's history but is not rung up.
  final bool active;

  /// #4366 -- the settings in force the till reads (the group's value, or the item's own): the category its key sits
  /// under, the key's colour (`#rrggbb`), the age a customer must have, whether it is weighed, and its deposit item.
  final String? tillCategory;
  final String? quickKeyColour;
  final int? minAge;
  final bool soldByWeight;
  final String? depositItemId;

  factory StockItem.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'services');
    return StockItem(
      id: r.string('id'),
      name: r.stringOr('name'),
      unit: r.stringOr('inventory_unit'),
      active: r.boolOr('active', fallback: true),
      tillCategory: r.stringOrNull('till_category'),
      quickKeyColour: r.stringOrNull('quick_key_colour'),
      minAge: r.intOrNull('min_age'),
      soldByWeight: r.boolOr('sold_by_weight', fallback: false),
      depositItemId: r.stringOrNull('deposit_item_id'),
    );
  }
}
