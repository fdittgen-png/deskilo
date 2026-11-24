// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4432 -- the Demo's chain of a lot, read from its own ledger as 0923 reads the server's: every movement of the lot,
// in order, with its places. The Demo keeps no documents on its movements and no piece history, so a step names no
// document and a piece's chain is its lot's. A sold line read backwards (#4436) names the track IDs the till froze on it;
// the Demo's till takes no goods from the ledger, so such a line has no movement to list.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/stock/domain/stock_config.dart';
import '../../../features/stock/domain/stock_page.dart';
import '../../../features/stock/domain/stock_trace_chain.dart';
import 'demo_stock_ledger.dart';
import 'demo_till.dart';

class DemoStockTraceChain implements StockTraceChainReader {
  DemoStockTraceChain(this._ledger, {this.sold});

  final DemoStockLedger _ledger;

  /// The traced lines the business's till sold; none without a till.
  final List<DemoSoldLine> Function()? sold;

  @override
  Future<TraceChain> chain(String workspaceId, {String? lotId, String? pieceId, String? movementId, String? counterLineId}) async {
    if (counterLineId != null) {
      final line = sold?.call().where((l) => l.lineId == counterLineId).firstOrNull;
      // an unknown line is refused, as the server refuses it
      if (line == null || !_ledger.mine(workspaceId)) throw const StockConfigRefused('counter_line_id', StockRefusal.unknown);
      return TraceChain(
        subject: 'sale_line',
        steps: const [],
        took: [
          for (final t in line.tracks)
            TraceTrack(kind: t.kind, code: t.code, quantity: t.quantity == null ? null : ExactQuantity.parse(t.quantity!)),
        ],
      );
    }
    final moves = _ledger.mine(workspaceId) ? _ledger.movements : const <StockMovementRow>[];
    final lot = lotId ?? moves.where((m) => m.id == movementId).firstOrNull?.lotId;
    final steps = [
      for (final m in moves)
        if ((lot != null && m.lotId == lot) || (lot == null && m.id == movementId))
          TraceStep(
            movementId: m.id,
            at: m.occurredAt,
            reason: m.reason,
            quantity: m.quantity,
            fromCode: m.fromLocationCode,
            toCode: m.toLocationCode,
          ),
    ]..sort((a, b) => a.at.compareTo(b.at));
    final code = moves.where((m) => m.lotId == lot).firstOrNull?.lotCode;
    return TraceChain(subject: lotId != null ? 'lot' : (pieceId != null ? 'piece' : 'movement'), lotCode: code, steps: steps);
  }
}
