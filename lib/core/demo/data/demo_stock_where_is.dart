// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4434 (G19) -- the Demo's "where is it", read through the same port as the server's. Not its own figures: the places
// are the ONE Demo ledger's movements replayed (now, or up to a date), the goods on the road are its open transfers, the
// pieces are the tags of its gift basket. Another Demo business keeps none.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_where_is.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'demo_stock_ledger.dart';
import 'demo_stock_tags.dart';

class DemoStockWhereIs implements StockWhereIs {
  DemoStockWhereIs(this._ledger, this._tags);

  final DemoStockLedger _ledger;
  final DemoStockTags _tags;

  @override
  Future<WhereIsAnswer> whereIs(String workspaceId, String itemId, {String? lotId, DateTime? at}) async {
    final item = _ledger.mine(workspaceId) ? _ledger.itemOf(itemId) : null;
    if (item == null) throw const StockConfigRefused('item_id', StockRefusal.itemUnknown);
    final places = await _ledger.placeConfigs();
    final moves = _ledger.core.movesOf(itemId, lotId: lotId, at: at);
    final rows = _ledger.core.whereIs(moves);
    var onHand = ExactQuantity.zero;
    for (final p in rows.where((p) => !p.isVirtual)) {
      onHand = onHand + p.quantity;
    }
    return WhereIsAnswer(
      itemId: item.id,
      itemName: item.name,
      unit: item.unit,
      lotId: lotId,
      asOf: at,
      onHand: onHand,
      places: rows,
      documents: _documents(moves, places),
      transit: at == null ? _transit(itemId, lotId) : null,
      pieces: at == null ? _pieces(itemId, places) : null,
    );
  }

  bool _leaves(String? kind) => kind == 'customer' || kind == 'loss';

  List<WhereIsDocument> _documents(List<StockMovementRow> moves, Map<String, StockPlaceConfig> places) => [
    for (final m in moves.take(20))
      if (_leaves(places[m.toLocationId]?.kind) || _leaves(places[m.fromLocationId]?.kind))
        WhereIsDocument(
          movementId: m.id,
          reason: m.reason,
          occurredAt: m.occurredAt,
          fromCode: m.fromLocationCode,
          toCode: m.toLocationCode,
          quantity: m.quantity,
          invoiceId: m.causes['invoice'],
          eventId: m.causes['event'],
        ),
  ];

  List<WhereIsTransit> _transit(String itemId, String? lotId) => [
    for (final t in _ledger.openTransfers)
      for (final l in t.lines)
        if (l.itemId == itemId && (lotId == null || l.lotId == lotId) && l.loaded > l.received)
          WhereIsTransit(transferId: t.id, fromCode: t.fromCode, toCode: t.toCode, quantity: l.loaded - l.received, lotId: l.lotId),
  ];

  List<WhereIsPiece> _pieces(String itemId, Map<String, StockPlaceConfig> places) => [
    for (final p in _tags.pieceTags(itemId))
      WhereIsPiece(pieceId: p.pieceId, state: 'in_stock', locationId: 'demo-place-main', locationCode: places['demo-place-main']?.code ?? 'MAIN', tags: [p.code]),
  ];
}
