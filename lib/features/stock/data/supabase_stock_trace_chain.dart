// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_trace_chain.dart';
import 'stock_rpc.dart';

/// #4432 -- `stock_trace_chain_v1` (0923) behind the port. An answer of the wrong shape throws: it is never shown as
/// an empty chain.
class SupabaseStockTraceChain implements StockTraceChainReader {
  SupabaseStockTraceChain(this._client);

  final SupabaseClient _client;

  @override
  Future<TraceChain> chain(String workspaceId, {String? lotId, String? pieceId, String? movementId, String? counterLineId}) async =>
      TraceChain.fromJson(
        await StockRpc(_client).object('stock_trace_chain_v1', {
          'p_workspace_id': workspaceId,
          'p_lot_id': ?lotId,
          'p_piece_id': ?pieceId,
          'p_movement_id': ?movementId,
          'p_counter_line_id': ?counterLineId,
        }),
      );
}
