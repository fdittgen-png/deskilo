// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4434 (G19) -- the Demo's "where is it", read through the same port as the server's. Not its own figures: the places
// are the ONE Demo ledger's movements replayed (now, or up to a date), the goods on the road are its open transfers, the
// pieces are the tags of its gift basket. Another Demo business keeps none.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_where_is.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../codes/dk_code.dart';
import 'demo_stock_ledger.dart';
import 'demo_stock_tags.dart';

class DemoStockWhereIs implements StockWhereIs {
  DemoStockWhereIs(this._ledger, this._tags);

  final DemoStockLedger _ledger;
  final DemoStockTags _tags;

  @override
  Future<WhereIsAnswer> whereIs(String workspaceId, String itemId, {String? lotId, DateTime? at}) async {
    final item = _ledger.mine(workspaceId) ? _ledger.itemOf(itemId) : null;
    if (item == null) throw const StockConfigRefused('item_id', DkCode.dkg04);
    final places = await _ledger.placeConfigs();
    // replay: every movement up to the date adds to its place and takes from the one it left
    final held = <String, ({String place, String? lotId, String? lotCode, ExactQuantity quantity})>{};
    void add(StockMovementRow m, String place, ExactQuantity q) {
      final key = '$place|${m.lotId ?? ''}';
      final was = held[key]?.quantity ?? ExactQuantity.zero;
      held[key] = (place: place, lotId: m.lotId, lotCode: m.lotCode, quantity: was + q);
    }

    final moves = [
      for (final m in _ledger.movements)
        if (m.itemId == itemId && (lotId == null || m.lotId == lotId) && (at == null || !m.occurredAt.isAfter(at))) m,
    ];
    for (final m in moves) {
      add(m, m.toLocationId, m.quantity);
      add(m, m.fromLocationId, ExactQuantity.zero - m.quantity);
    }
    final rows = [
      for (final h in held.values)
        if (h.quantity != ExactQuantity.zero)
          WhereIsPlace(
            locationId: h.place,
            locationCode: places[h.place]?.code ?? '',
            locationName: places[h.place]?.name ?? '',
            locationKind: places[h.place]?.kind ?? '',
            isVirtual: places[h.place]?.virtual ?? false,
            quantity: h.quantity,
            lotId: h.lotId,
            lotCode: h.lotCode,
          ),
    ]..sort((a, b) => a.isVirtual == b.isVirtual ? a.locationCode.compareTo(b.locationCode) : (a.isVirtual ? 1 : -1));
    var onHand = ExactQuantity.zero;
    for (final p in rows.where((p) => !p.isVirtual)) {
      onHand = onHand + p.quantity;
    }
    final pieces = at == null
        ? [
            for (final p in _tags.pieceTags(itemId))
              WhereIsPiece(pieceId: p.pieceId, state: 'in_stock', locationId: 'demo-place-main', locationCode: places['demo-place-main']?.code ?? 'MAIN', tags: [p.code]),
          ]
        : null;
    return WhereIsAnswer(
      itemId: item.id,
      itemName: item.name,
      unit: item.unit,
      lotId: lotId,
      asOf: at,
      onHand: onHand,
      places: rows,
      documents: [
        for (final m in moves.take(20))
          if ((places[m.toLocationId]?.kind == 'customer' || places[m.toLocationId]?.kind == 'loss') ||
              (places[m.fromLocationId]?.kind == 'customer' || places[m.fromLocationId]?.kind == 'loss'))
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
      ],
      transit: at != null
          ? null
          : [
              for (final t in _ledger.openTransfers)
                for (final l in t.lines)
                  if (l.itemId == itemId && (lotId == null || l.lotId == lotId) && l.loaded > l.received)
                    WhereIsTransit(transferId: t.id, fromCode: t.fromCode, toCode: t.toCode, quantity: l.loaded - l.received, lotId: l.lotId),
            ],
      pieces: pieces,
    );
  }
}
