// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_trace.dart';
import 'stock_rpc.dart';

/// #4173 -- `stock_goods_trace_v1`, `stock_document_goods_v1` and `stock_valuation_v1` behind the
/// port. An answer of the wrong shape throws: it is never shown as an empty trace.
class SupabaseStockTrace implements StockTraceReader {
  SupabaseStockTrace(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, Map<String, Object?> params) => StockRpc(_client).run(fn, params);

  @override
  Future<StockTraceAnswer> trace(String workspaceId, String movementId) async => StockTraceAnswer.fromJson(
    await _call('stock_goods_trace_v1', {'p_workspace_id': workspaceId, 'p_movement_id': movementId}),
  );

  @override
  Future<DocumentGoods> documentGoods(
    String workspaceId,
    String kind,
    String id, {
    int limit = 50,
    Map<String, Object?>? after,
  }) async => DocumentGoods.fromJson(
    await _call('stock_document_goods_v1', {
      'p_workspace_id': workspaceId,
      'p_kind': kind,
      'p_id': id,
      'p_limit': limit,
      'p_after': after,
    }),
  );

  @override
  Future<StockValuation> valuation(String workspaceId, {DateTime? at}) async => StockValuation.fromJson(
    await _call('stock_valuation_v1', {'p_workspace_id': workspaceId, 'p_at': at?.toUtc().toIso8601String()}),
  );
}
