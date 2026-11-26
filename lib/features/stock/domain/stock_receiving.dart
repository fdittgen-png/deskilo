// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4171 (A) -- receiving a purchase-order delivery into stock, as the screens
// ask for it: what is put away of each delivered line (into which place, as
// which variant, in which new lot, at which cost), and what the server wrote.
// A delivery is recorded first (0684) or in the same transaction; a put-away
// never exceeds what arrived, makes its own new lots and never guesses a
// cost: unknown is unknown, a known zero is zero. The server answers a
// repeated request id with the same ids.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'stock_config.dart';

/// What a put-away says the goods cost; never implied.
sealed class PutAwayCost {
  const PutAwayCost();

  /// No cost is asserted: the lot's cost is unknown (not zero).
  const factory PutAwayCost.unknown() = UnknownCost;

  /// A cost the person entered, in minor units of the business's currency,
  /// with the currency and rate it came from when it was not that currency.
  const factory PutAwayCost.known({
    required int totalMinor,
    String? sourceCurrency,
    String? sourceRate,
  }) = KnownCost;

  /// The order line's own price, asserted explicitly; a foreign-currency
  /// order needs its [sourceRate].
  const factory PutAwayCost.orderPrice({String? sourceRate}) = OrderPriceCost;

  Map<String, Object?> toJson();
}

final class UnknownCost extends PutAwayCost {
  const UnknownCost();

  @override
  Map<String, Object?> toJson() => {'state': 'unknown'};
}

final class KnownCost extends PutAwayCost {
  const KnownCost({required this.totalMinor, this.sourceCurrency, this.sourceRate});

  final int totalMinor;
  final String? sourceCurrency;
  final String? sourceRate;

  @override
  Map<String, Object?> toJson() => {
    'state': 'known',
    'total_cost_minor': totalMinor,
    'source_currency': ?sourceCurrency,
    'source_rate': ?sourceRate,
  };
}

final class OrderPriceCost extends PutAwayCost {
  const OrderPriceCost({this.sourceRate});

  final String? sourceRate;

  @override
  Map<String, Object?> toJson() => {
    'state': 'order_price',
    'source_rate': ?sourceRate,
  };
}

/// One part of a put-away: [quantity] (in the unit of the order line, an
/// exact decimal text) of one delivered line into one place.
class PutAwayAllocation {
  const PutAwayAllocation({
    required this.lineNo,
    required this.quantity,
    required this.locationId,
    this.variantId,
    this.group,
    this.lotCode,
    this.expiresOn,
    this.cost = const PutAwayCost.unknown(),
    this.tags = const [],
    this.unit,
  });

  /// The number of the order line the delivery brought.
  final int lineNo;
  final String quantity;

  /// #4479 -- the unit [quantity] is counted in, when it is not the order line's (a carton ordered, pieces put away); null: the line's.
  final String? unit;
  final String locationId;
  final String? variantId;

  /// Parts of one line and variant that share a group make one new lot.
  final String? group;
  final String? lotCode;

  /// `YYYY-MM-DD`; a past date is kept as entered.
  final String? expiresOn;
  final PutAwayCost cost;

  /// #4379 -- the tag of each piece, for an item tagged piece by piece: as many as the allocation holds in the
  /// item's inventory unit. The server makes one piece per tag at the place, with the movement (0889).
  final List<String> tags;

  Map<String, Object?> toJson() => {
    'line_no': lineNo,
    'quantity': quantity,
    'unit': ?unit,
    'location_id': locationId,
    'variant_id': ?variantId,
    'group': ?group,
    if (lotCode != null || expiresOn != null)
      'lot': {'code': ?lotCode, 'expires_on': ?expiresOn},
    'cost': cost.toJson(),
    if (tags.isNotEmpty) 'units': [for (final t in tags) {'tag': t}],
  };
}

/// What was put away, as the server froze it.
class ReceiptAllocation {
  const ReceiptAllocation({
    required this.id,
    required this.receiptLineId,
    required this.itemId,
    required this.variantId,
    required this.lotId,
    required this.locationId,
    required this.movementId,
    required this.enteredQuantity,
    required this.inventoryQuantity,
    this.lineNo = 0,
    this.enteredUnit = '',
    this.orderReference = '',
    this.supplierName = '',
    this.lineText = '',
  });

  factory ReceiptAllocation.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_receipt_allocations');
    return ReceiptAllocation(
      id: r.string('id'),
      receiptLineId: r.string('receipt_line_id'),
      itemId: r.string('item_id'),
      variantId: r.stringOrNull('variant_id'),
      lotId: r.string('lot_id'),
      locationId: r.string('location_id'),
      movementId: r.string('movement_id'),
      enteredQuantity: ExactQuantity.parse(r.string('entered_quantity')),
      inventoryQuantity: ExactQuantity.parse(r.string('inventory_quantity')),
      lineNo: r.objectOrNull('purchase_order_lines')?.integer('line_no') ?? 0,
      enteredUnit: r.stringOr('entered_unit'),
      orderReference: r.stringOr('order_reference'),
      supplierName: r.stringOr('supplier_name'),
      lineText: r.stringOr('line_text'),
    );
  }

  final String id;
  final String receiptLineId;
  final String itemId;
  final String? variantId;
  final String lotId;
  final String locationId;
  final String movementId;

  /// The number of the order line it came from (0 when the read did not say).
  final int lineNo;

  /// In the unit of the order line, as the delivery counted it.
  final ExactQuantity enteredQuantity;

  /// In the item's inventory unit, rounded once.
  final ExactQuantity inventoryQuantity;
  final String enteredUnit;

  /// What the order said when the goods were put away.
  final String orderReference;
  final String supplierName;
  final String lineText;
}

/// What a put-away answered.
typedef PutAwayResult = ({String receiptId, bool replayed, List<ReceiptAllocation> allocations});

/// One line of a delivery being recorded: the order line and how much arrived.
typedef DeliveredLine = ({int lineNo, String quantity});

/// A delivery to record: the order at the revision read, the day, the lines.
class DeliveryDraft {
  const DeliveryDraft({
    required this.orderId,
    required this.orderRevision,
    required this.receivedOn,
    required this.lines,
    this.note = '',
  });

  final String orderId;
  final int orderRevision;

  /// `YYYY-MM-DD`.
  final String receivedOn;
  final List<DeliveredLine> lines;
  final String note;
}

abstract interface class StockReceivingCommands {
  /// What was put away of one delivery, oldest first.
  Future<List<ReceiptAllocation>> allocations(String workspaceId, String receiptId);

  /// What was put away of every delivery of one order, oldest first.
  Future<List<ReceiptAllocation>> allocationsOfOrder(String workspaceId, String orderId);

  /// Puts away (more of) a recorded delivery.
  Future<PutAwayResult> putAway(
    String workspaceId,
    String receiptId,
    List<PutAwayAllocation> allocations,
    String requestId,
  );

  /// Records a delivery and puts it away in one transaction: both, or neither.
  Future<PutAwayResult> recordAndPutAway(
    String workspaceId,
    DeliveryDraft delivery,
    List<PutAwayAllocation> allocations,
    String requestId,
  );
}

/// #4479 -- the units a put-away of [item]'s order line may be counted in: the line's own unit, the item's inventory unit and the units of its
/// own conversions (the server also accepts a unit with a general conversion; the pickers offer the ones the item itself names).
List<String> putAwayUnits(StockItemConfig item, String lineUnit) => {
  if (lineUnit.isNotEmpty) lineUnit,
  item.inventoryUnit,
  for (final u in item.units) u.unit,
}.toList();
