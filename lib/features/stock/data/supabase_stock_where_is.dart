// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_where_is.dart';
import 'stock_rpc.dart';

/// #4434 (G19) -- `stock_where_is_v1` behind the port: one read for the places of an item or lot, now or as of a date.
class SupabaseStockWhereIs implements StockWhereIs {
  SupabaseStockWhereIs(this._client);

  final SupabaseClient _client;

  @override
  Future<WhereIsAnswer> whereIs(String workspaceId, String itemId, {String? lotId, DateTime? at}) async => WhereIsAnswer.fromJson(
    await StockRpc(_client).object('stock_where_is_v1', {
      'p_workspace_id': workspaceId,
      'p_item_id': itemId,
      'p_lot_id': lotId,
      'p_at': at?.toUtc().toIso8601String(),
    }),
  );
}
