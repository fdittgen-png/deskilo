// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_page.dart';
import '../domain/stock_queries.dart';

/// #4161 (A1) -- `stock_on_hand_page_v1` and `stock_movements_page_v1` behind
/// the port. A page whose shape is wrong, whose continuation is missing or
/// whose row cannot be read throws: it is never shown as an empty or
/// complete list.
class SupabaseStockQueries implements StockQueries {
  SupabaseStockQueries(this._client);

  final SupabaseClient _client;

  @override
  Future<StockPage<StockOnHandRow>> onHandPage(
    String workspaceId, {
    String? itemId,
    String? locationId,
    int limit = 50,
    StockCursor? after,
  }) => _page(
    'stock_on_hand_page_v1',
    _params(workspaceId, itemId, locationId, limit, after),
    StockOnHandRow.fromJson,
  );

  @override
  Future<StockPage<StockMovementRow>> movementsPage(
    String workspaceId, {
    String? itemId,
    String? locationId,
    int limit = 50,
    StockCursor? after,
  }) => _page(
    'stock_movements_page_v1',
    _params(workspaceId, itemId, locationId, limit, after),
    StockMovementRow.fromJson,
  );

  @override
  Future<StockMovementRow?> movement(
    String workspaceId,
    String movementId,
  ) async {
    final page = await _page(
      'stock_movements_page_v1',
      {
        ..._params(workspaceId, null, null, 1, null),
        'p_movement_id': movementId,
      },
      StockMovementRow.fromJson,
    );
    return page.rows.firstOrNull;
  }

  @override
  Future<List<StockPlace>> places(String workspaceId) async {
    final rows = await _client
        .from('stock_locations')
        .select('id, code, name')
        .eq('workspace_id', workspaceId)
        .eq('active', true)
        .order('code');
    return [for (final row in rows) StockPlace.fromJson(row)];
  }

  @override
  Future<List<StockItem>> items(String workspaceId) async {
    final rows = await _client
        .from('services')
        .select('id, name, inventory_unit, active')
        .eq('workspace_id', workspaceId)
        .eq('stockable', true)
        .order('name');
    return [for (final row in rows) StockItem.fromJson(row)];
  }

  @override
  Future<List<StockItem>> unstocked(String workspaceId) async {
    final rows = await _client
        .from('services')
        .select('id, name, inventory_unit')
        .eq('workspace_id', workspaceId)
        .eq('stockable', false)
        .eq('active', true)
        .order('name');
    return [for (final row in rows) StockItem.fromJson(row)];
  }

  Map<String, Object?> _params(
    String workspaceId,
    String? itemId,
    String? locationId,
    int limit,
    StockCursor? after,
  ) => {
    'p_workspace_id': workspaceId,
    'p_item_id': itemId,
    'p_location_id': locationId,
    'p_limit': limit,
    'p_after': after,
  };

  Future<StockPage<T>> _page<T>(
    String rpc,
    Map<String, Object?> params,
    T Function(Object? row) read,
  ) async {
    final answer = await _client.rpc<Object?>(rpc, params: params);
    final reader = JsonReader.of(answer, context: rpc);
    final complete = reader.boolOr('complete', fallback: false);
    final next = reader.objectOrNull('next')?.json;
    if (!complete && next == null) {
      // A page that neither ends nor continues would silently truncate.
      throw StockReadException('$rpc: no continuation');
    }
    return StockPage(
      rows: [for (final row in reader.requiredList('rows')) read(row)],
      complete: complete,
      next: complete ? null : next,
    );
  }
}
