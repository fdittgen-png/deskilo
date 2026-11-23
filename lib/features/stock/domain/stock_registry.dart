// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4293 (G7, cut B) -- the product and place registry: one row per item (per variant when it
// has any) with its barcode, unit, retail price, last known cost, home address and what is on
// hand. The cost reaches only whoever may see finances or manage purchases; an unknown cost is
// null, never zero. A home place is advice for put-away, counting and picking, never a balance.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'stock_page.dart';

/// One line of the registry: an item, or one variant of an item.
class StockRegistryRow {
  const StockRegistryRow({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.onHand,
    this.variantId,
    this.variantLabel,
    this.barcode,
    this.priceCents,
    this.cost,
    this.costVisible = false,
    this.homeLocationId,
    this.homeCode,
    this.homeAddressPath,
  });

  final String itemId;
  final String itemName;
  final String? variantId;
  final String? variantLabel;
  final String? barcode;
  final String unit;

  /// The catalogue sale price of the item or variant, in minor units.
  final int? priceCents;

  /// The last known purchase cost of one inventory unit, in minor units (a decimal text); null
  /// when none is known. Only meaningful when [costVisible].
  final String? cost;

  /// False when the reader may not see what goods cost: the screen says "cost not shown".
  final bool costVisible;

  /// The place the item belongs at, its code and the codes of its parents joined by
  /// `stockAddressJoint`; null when it has no home place.
  final String? homeLocationId;
  final String? homeCode;
  final String? homeAddressPath;
  final ExactQuantity onHand;

  /// Two rows of one item differ by variant: the key of a row in lists and tests.
  String get key => variantId == null ? itemId : '$itemId-$variantId';

  /// The item with its variant, as a person reads it.
  String get label => variantLabel == null ? itemName : '$itemName · $variantLabel';

  /// The last known cost in minor units, rounded; null when unknown or not shown.
  int? get costMinor {
    if (!costVisible || cost == null) return null;
    // #4393 -- read exactly and rounded half away from zero, as the server rounds money; no binary float between.
    final exact = ExactQuantity.tryParse(cost!).value;
    return exact?.scaled(1, 1000000, round: true).value?.micro.toInt();
  }

  factory StockRegistryRow.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_registry_page_v1');
    return StockRegistryRow(
      itemId: r.string('item_id'),
      itemName: r.stringOr('item_name'),
      variantId: r.stringOrNull('variant_id'),
      variantLabel: r.stringOrNull('variant_label'),
      barcode: r.stringOrNull('barcode'),
      unit: r.stringOr('unit'),
      priceCents: r.intOrNull('price_cents'),
      cost: r.stringOrNull('cost'),
      costVisible: r.boolOr('cost_visible', fallback: false),
      homeLocationId: r.stringOrNull('home_location_id'),
      homeCode: r.stringOrNull('home_code'),
      homeAddressPath: r.stringOrNull('home_address_path'),
      onHand: ExactQuantity.parse(r.string('on_hand')),
    );
  }
}

/// The registry's reads and its one command.
abstract interface class StockRegistry {
  /// At most [limit] rows (1..200), by name; [placeId] keeps what is homed in that place or below
  /// it, [noHome] what has no home place.
  Future<StockPage<StockRegistryRow>> page(
    String workspaceId, {
    String? placeId,
    bool noHome = false,
    int limit = 50,
    StockCursor? after,
  });

  /// Names [placeId] (null: clears it) as the home of the item or one of its variants. Moves
  /// nothing and writes no history; a request id answers once.
  Future<void> setHome(
    String workspaceId, {
    required String itemId,
    required String? variantId,
    required String? placeId,
    required String requestId,
  });
}
