// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4434 (G19) -- "where is it": every place that holds an item or one of its lots, with the quantity, variant and lot,
// now or as of a past date; the goods loaded for another site with their from and to; what left to a customer or a loss
// or came back, with the movement that moved it; the pieces with their place, state and tags. The answer balances: the
// real places add up to [onHand]. Pure: the port, the answer and what a person reads off it.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// One place that holds the item, with what it holds there.
class WhereIsPlace {
  const WhereIsPlace({
    required this.locationId,
    required this.locationCode,
    required this.locationName,
    required this.locationKind,
    required this.isVirtual,
    required this.quantity,
    this.variantId,
    this.variantLabel,
    this.lotId,
    this.lotCode,
    this.expiresOn,
  });

  factory WhereIsPlace.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_where_is_v1.places');
    return WhereIsPlace(
      locationId: r.string('location_id'),
      locationCode: r.string('location_code'),
      locationName: r.stringOr('location_name'),
      locationKind: r.string('location_kind'),
      isVirtual: r.boolOr('virtual', fallback: false),
      quantity: ExactQuantity.parse(r.string('quantity')),
      variantId: r.stringOrNull('variant_id'),
      variantLabel: r.stringOrNull('variant_label'),
      lotId: r.stringOrNull('lot_id'),
      lotCode: r.stringOrNull('lot_code'),
      expiresOn: r.stringOrNull('expires_on'),
    );
  }

  final String locationId;
  final String locationCode;
  final String locationName;

  /// The kind of the place (`warehouse`, `shelf`, `in_transit`, `customer`, `loss`, `supplier`...).
  final String locationKind;

  /// A virtual place is where goods are that left the business or came from outside; it is not a shelf.
  final bool isVirtual;
  final ExactQuantity quantity;
  final String? variantId;
  final String? variantLabel;
  final String? lotId;
  final String? lotCode;
  final String? expiresOn;
}

/// Goods loaded for another site and not yet received: from which place, to which.
class WhereIsTransit {
  const WhereIsTransit({required this.transferId, required this.fromCode, required this.toCode, required this.quantity, this.variantId, this.lotId});

  factory WhereIsTransit.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_where_is_v1.transit');
    return WhereIsTransit(
      transferId: r.string('transfer_id'),
      fromCode: r.string('from_location_code'),
      toCode: r.string('to_location_code'),
      quantity: ExactQuantity.parse(r.string('quantity')),
      variantId: r.stringOrNull('variant_id'),
      lotId: r.stringOrNull('lot_id'),
    );
  }

  final String transferId;
  final String fromCode;
  final String toCode;
  final ExactQuantity quantity;
  final String? variantId;
  final String? lotId;
}

/// A movement that took goods to a customer or a loss, or brought them back: the document it came from.
class WhereIsDocument {
  const WhereIsDocument({
    required this.movementId,
    required this.reason,
    required this.occurredAt,
    required this.fromCode,
    required this.toCode,
    required this.quantity,
    this.invoiceId,
    this.eventId,
  });

  factory WhereIsDocument.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_where_is_v1.documents');
    return WhereIsDocument(
      movementId: r.string('movement_id'),
      reason: r.string('reason'),
      occurredAt: r.dateTime('occurred_at'),
      fromCode: r.string('from_location_code'),
      toCode: r.string('to_location_code'),
      quantity: ExactQuantity.parse(r.string('quantity')),
      invoiceId: r.stringOrNull('invoice_id'),
      eventId: r.stringOrNull('event_id'),
    );
  }

  final String movementId;
  final String reason;
  final DateTime occurredAt;
  final String fromCode;
  final String toCode;
  final ExactQuantity quantity;
  final String? invoiceId;
  final String? eventId;
}

/// One tagged piece of the item, at exactly one place.
class WhereIsPiece {
  const WhereIsPiece({required this.pieceId, required this.state, required this.locationId, required this.locationCode, required this.tags, this.variantId, this.lotId});

  factory WhereIsPiece.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_where_is_v1.pieces');
    return WhereIsPiece(
      pieceId: r.string('piece_id'),
      state: r.string('state'),
      locationId: r.string('location_id'),
      locationCode: r.string('location_code'),
      tags: [for (final t in r.requiredList('tags')) '$t'],
      variantId: r.stringOrNull('variant_id'),
      lotId: r.stringOrNull('lot_id'),
    );
  }

  final String pieceId;
  final String state;
  final String locationId;
  final String locationCode;
  final List<String> tags;
  final String? variantId;
  final String? lotId;
}

/// What `stock_where_is_v1` answered.
class WhereIsAnswer {
  const WhereIsAnswer({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.onHand,
    required this.places,
    required this.documents,
    this.lotId,
    this.asOf,
    this.transit,
    this.pieces,
    this.piecesMore = false,
    this.piecesKnownFrom,
  });

  factory WhereIsAnswer.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_where_is_v1');
    final item = JsonReader.of(r.raw('item'), context: 'stock_where_is_v1.item');
    return WhereIsAnswer(
      itemId: item.string('id'),
      itemName: item.stringOr('name'),
      unit: item.string('unit'),
      lotId: r.stringOrNull('lot_id'),
      asOf: r.dateTimeOrNull('as_of'),
      onHand: ExactQuantity.parse(r.string('on_hand')),
      places: [for (final p in r.requiredList('places')) WhereIsPlace.fromJson(p)],
      documents: [for (final d in r.requiredList('documents')) WhereIsDocument.fromJson(d)],
      transit: r.raw('transit') is List ? [for (final t in r.requiredList('transit')) WhereIsTransit.fromJson(t)] : null,
      pieces: r.raw('pieces') is List ? [for (final p in r.requiredList('pieces')) WhereIsPiece.fromJson(p)] : null,
      piecesMore: r.boolOr('pieces_more', fallback: false),
      piecesKnownFrom: r.dateTimeOrNull('pieces_known_from'),
    );
  }

  final String itemId;
  final String itemName;
  final String unit;
  final String? lotId;

  /// The date this answer is as of; null for now.
  final DateTime? asOf;

  /// What the real places hold together.
  final ExactQuantity onHand;
  final List<WhereIsPlace> places;
  final List<WhereIsDocument> documents;

  /// The goods in transit with their from and to; null at a past date (a transfer does not keep its past states).
  final List<WhereIsTransit>? transit;

  /// The tagged pieces: now, or at a past date replayed from the movement-piece link.
  final List<WhereIsPiece>? pieces;
  final bool piecesMore;

  /// Since when the movement-piece link is kept: a piece made before has no history before it.
  final DateTime? piecesKnownFrom;

  /// The places on a shelf (not virtual).
  Iterable<WhereIsPlace> get real => places.where((p) => !p.isVirtual);

  /// The answer balances when the real places add up to [onHand].
  bool get balances {
    var sum = ExactQuantity.zero;
    for (final p in real) {
      sum = sum + p.quantity;
    }
    return sum == onHand;
  }
}

/// The port: one read, now or as of [at].
abstract interface class StockWhereIs {
  Future<WhereIsAnswer> whereIs(String workspaceId, String itemId, {String? lotId, DateTime? at});
}
