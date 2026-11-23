// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_code_resolver.dart';
import 'stock_rpc.dart';

/// #4359 -- `stock_resolve_code_v1` behind the port. The server never throws for an unknown code (it answers
/// kind `unknown`); a refusal (no right to read the stock) or an answer of the wrong shape throws here, and is
/// never taken for "unknown".
class SupabaseStockCodeResolver implements StockCodeResolver {
  SupabaseStockCodeResolver(this._client);

  final SupabaseClient _client;

  @override
  Future<StockCodeResolution> resolve(String workspaceId, String code) async {
    return StockRpc(_client).guard('a scanned code', () async {
      return StockCodeResolution.fromJson(
        await _client.rpc<Object?>('stock_resolve_code_v1', params: {'p_workspace_id': workspaceId, 'p_code': code}),
      );
    });
  }
}
