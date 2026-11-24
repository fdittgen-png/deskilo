// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The trace read from a track ID, as `stock_trace_find_v1` (0940) answers it: a code typed or scanned (a lot code as
// received, a lot's label code or a piece's tag) names the lots and pieces of this business that carry it and the
// counter sales that took them. A sale's receipt is named only to a reader who may see it; otherwise its kind alone is
// known, never left out. Pieces are null where the business does not use tags. Each list is bounded and `truncated`
// says when there were more.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'stock_trace_chain.dart';

/// A lot the code names.
class TrackFindLot {
  const TrackFindLot({
    required this.id,
    required this.itemId,
    required this.item,
    this.code,
    this.labelCode,
    this.expiresOn,
  });

  final String id;
  final String itemId;
  final String item;

  /// The lot code as received; null when the lot has only a label code.
  final String? code;
  final String? labelCode;
  final DateTime? expiresOn;

  factory TrackFindLot.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_trace_find.lots');
    final expires = r.stringOrNull('expires_on');
    return TrackFindLot(
      id: r.string('id'),
      itemId: r.string('item_id'),
      item: r.stringOr('item'),
      code: r.stringOrNull('code'),
      labelCode: r.stringOrNull('label_code'),
      expiresOn: expires == null ? null : DateTime.parse(expires),
    );
  }
}

/// A piece whose tag the code is.
class TrackFindPiece {
  const TrackFindPiece({
    required this.id,
    required this.itemId,
    required this.item,
    required this.tag,
    this.lotId,
    this.state,
  });

  final String id;
  final String itemId;
  final String item;
  final String tag;
  final String? lotId;
  final String? state;

  factory TrackFindPiece.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_trace_find.pieces');
    return TrackFindPiece(
      id: r.string('id'),
      itemId: r.string('item_id'),
      item: r.stringOr('item'),
      tag: r.stringOr('tag'),
      lotId: r.stringOrNull('lot_id'),
      state: r.stringOrNull('state'),
    );
  }
}

/// A counter sale line that took a lot or a piece the code names.
class TrackFindSale {
  const TrackFindSale({
    required this.at,
    required this.quantity,
    this.document,
    this.lineId,
  });

  final DateTime at;

  /// What the line took of what the code names.
  final ExactQuantity quantity;

  /// The receipt; unavailable (its kind alone) to a reader who may not see it.
  final TraceDocument? document;

  /// The receipt line, known only with the receipt: it opens what the line took.
  final String? lineId;

  factory TrackFindSale.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_trace_find.sales');
    final document = r.objectOrNull('document');
    return TrackFindSale(
      at: DateTime.parse(r.string('at')),
      quantity: ExactQuantity.parse(r.string('quantity')),
      document: TraceDocument.fromJson(document?.json),
      lineId: document?.stringOrNull('line_id'),
    );
  }
}

/// The answer for one code.
class TrackFindAnswer {
  const TrackFindAnswer({
    required this.code,
    required this.lots,
    required this.sales,
    this.pieces,
    this.truncated = false,
  });

  /// The code as the server read it (trimmed).
  final String code;
  final List<TrackFindLot> lots;

  /// Null where the business does not use tags.
  final List<TrackFindPiece>? pieces;
  final List<TrackFindSale> sales;
  final bool truncated;

  /// Nothing of this business carries the code.
  bool get isEmpty =>
      lots.isEmpty && (pieces?.isEmpty ?? true) && sales.isEmpty;

  factory TrackFindAnswer.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_trace_find');
    // the server answers null pieces where the business does not use tags
    final pieces = r.raw('pieces') is List ? r.listOrAbsent('pieces') : null;
    return TrackFindAnswer(
      code: r.stringOr('code'),
      lots: [for (final l in r.requiredList('lots')) TrackFindLot.fromJson(l)],
      pieces: pieces == null
          ? null
          : [for (final p in pieces) TrackFindPiece.fromJson(p)],
      sales: [
        for (final s in r.requiredList('sales')) TrackFindSale.fromJson(s),
      ],
      truncated: r.boolOr('truncated', fallback: false),
    );
  }
}

abstract interface class StockTrackFinder {
  /// What of [workspaceId] carries [code], and the sales that took it.
  Future<TrackFindAnswer> find(String workspaceId, String code);
}
