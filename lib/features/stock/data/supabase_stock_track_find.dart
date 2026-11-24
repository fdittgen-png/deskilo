// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_track_find.dart';
import 'stock_rpc.dart';

/// `stock_trace_find_v1` (0940) behind the port. An answer of the wrong shape throws: it is never shown as "nothing
/// carries this code".
class SupabaseStockTrackFind implements StockTrackFinder {
  SupabaseStockTrackFind(this._client);

  final SupabaseClient _client;

  @override
  Future<TrackFindAnswer> find(String workspaceId, String code) async =>
      TrackFindAnswer.fromJson(
        await StockRpc(_client).object('stock_trace_find_v1', {
          'p_workspace_id': workspaceId,
          'p_code': code,
        }),
      );
}
