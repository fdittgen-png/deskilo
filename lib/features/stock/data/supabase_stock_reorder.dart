// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_config.dart' show StockSaved;
import '../domain/stock_reorder.dart';
import 'stock_rpc.dart';

/// #4294 -- `stock_low_v1`, `stock_replenishment_v1` and `create_replenishment_draft_v1` behind the
/// port. An answer of the wrong shape throws: it is never shown as an empty list.
class SupabaseStockReorder implements StockReorder {
  SupabaseStockReorder(this._client);

  final SupabaseClient _client;

  @override
  Future<List<StockReorderPoint>> points(String workspaceId) async {
    // the quantities are read as text: exact, never through a floating-point number
    final rows = await StockRpc(_client).rows('stock_reorder_points', _client
        .from('stock_reorder_points')
        .select('id, revision, item_id, variant_id, site_id, reorder_point::text, reorder_quantity::text, target_quantity::text, active')
        .eq('workspace_id', workspaceId)
        .order('created_datetime'));
    return [for (final row in rows) StockReorderPoint.fromJson(row)];
  }

  @override
  Future<StockSaved> savePoint(
    String workspaceId, {
    required Map<String, Object?> point,
    required String requestId,
    String? pointId,
    int? expectedRevision,
  }) async {
    return StockRpc(_client).guard('a reorder point', () async {
      final answer = await StockRpc(_client).run(
        'save_stock_reorder_point_v1',
        {
          'p_workspace_id': workspaceId,
          'p_point_id': pointId,
          'p_expected_revision': expectedRevision,
          'p_request_id': requestId,
          'p_point': point,
        },
      );
      final r = JsonReader.of(answer, context: 'save_stock_reorder_point_v1');
      return (id: r.string('point_id'), revision: r.integer('revision'), replayed: r.boolOr('replayed', fallback: false));
    });
  }

  @override
  Future<List<StockLowRow>> low(String workspaceId, {String? siteId}) async {
    final answer = await StockRpc(_client).run(
      'stock_low_v1',
      {'p_workspace_id': workspaceId, 'p_site_id': siteId},
    );
    final r = JsonReader.of(answer, context: 'stock_low_v1');
    return [for (final row in r.requiredList('rows')) StockLowRow.fromJson(row)];
  }

  @override
  Future<ReplenishmentList> replenishment(String workspaceId, {String? siteId}) async {
    final answer = await StockRpc(_client).run(
      'stock_replenishment_v1',
      {'p_workspace_id': workspaceId, 'p_site_id': siteId},
    );
    return ReplenishmentList.fromJson(answer);
  }

  @override
  Future<ReplenishmentDraft> createDraft(
    String workspaceId, {
    required String supplierId,
    required List<ReplenishmentLine> lines,
    required String requestId,
  }) async {
    final answer = await StockRpc(_client).run(
      'create_replenishment_draft_v1',
      {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_supplier_id': supplierId,
        'p_lines': [
          for (final l in lines)
            {'item_id': l.itemId, 'variant_id': l.variantId, 'quantity': l.quantity.text},
        ],
      },
    );
    final r = JsonReader.of(answer, context: 'create_replenishment_draft_v1');
    return (orderId: r.stringOrNull('id'), number: r.stringOrNull('number'));
  }
}
