// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4432 -- the Demo's chain of a lot, read from its own ledger as 0923 reads the server's: every movement of the lot,
// in order, with its places. The Demo keeps no documents on its movements and no piece history, so a step names no
// document and a piece's chain is its lot's.
import '../../../features/stock/domain/stock_page.dart';
import '../../../features/stock/domain/stock_trace_chain.dart';
import 'demo_stock_ledger.dart';

class DemoStockTraceChain implements StockTraceChainReader {
  DemoStockTraceChain(this._ledger);

  final DemoStockLedger _ledger;

  @override
  Future<TraceChain> chain(String workspaceId, {String? lotId, String? pieceId, String? movementId}) async {
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
