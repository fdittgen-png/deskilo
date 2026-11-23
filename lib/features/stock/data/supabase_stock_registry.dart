// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_page.dart';
import '../domain/stock_queries.dart';
import '../domain/stock_registry.dart';
import 'stock_rpc.dart';

/// #4293 -- `stock_registry_page_v1` and `set_stock_home_v1` behind the port. A page whose shape
/// is wrong or that neither ends nor continues throws: it is never shown as an empty list.
class SupabaseStockRegistry implements StockRegistry {
  SupabaseStockRegistry(this._client);

  final SupabaseClient _client;

  @override
  Future<StockPage<StockRegistryRow>> page(
    String workspaceId, {
    String? placeId,
    bool noHome = false,
    int limit = 50,
    StockCursor? after,
  }) async {
    final answer = await StockRpc(_client).run(
      'stock_registry_page_v1',
      {
        'p_workspace_id': workspaceId,
        'p_location_id': placeId,
        'p_no_home': noHome,
        'p_limit': limit,
        'p_after': after,
      },
    );
    final reader = JsonReader.of(answer, context: 'stock_registry_page_v1');
    final complete = reader.boolOr('complete', fallback: false);
    final next = reader.objectOrNull('next')?.json;
    if (!complete && next == null) throw const StockReadException('stock_registry_page_v1: no continuation');
    return StockPage(
      rows: [for (final row in reader.requiredList('rows')) StockRegistryRow.fromJson(row)],
      complete: complete,
      next: complete ? null : next,
    );
  }

  @override
  Future<void> setHome(
    String workspaceId, {
    required String itemId,
    required String? variantId,
    required String? placeId,
    required String requestId,
  }) async {
    await StockRpc(_client).run(
      'set_stock_home_v1',
      {
        'p_workspace_id': workspaceId,
        'p_item_id': itemId,
        'p_variant_id': variantId,
        'p_location_id': placeId,
        'p_request_id': requestId,
      },
    );
  }
}
