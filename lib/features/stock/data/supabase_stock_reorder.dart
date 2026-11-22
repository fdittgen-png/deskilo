// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_reorder.dart';

/// #4294 -- `stock_low_v1`, `stock_replenishment_v1` and `create_replenishment_draft_v1` behind the
/// port. An answer of the wrong shape throws: it is never shown as an empty list.
class SupabaseStockReorder implements StockReorder {
  SupabaseStockReorder(this._client);

  final SupabaseClient _client;

  @override
  Future<List<StockLowRow>> low(String workspaceId, {String? siteId}) async {
    final answer = await _client.rpc<Object?>(
      'stock_low_v1',
      params: {'p_workspace_id': workspaceId, 'p_site_id': siteId},
    );
    final r = JsonReader.of(answer, context: 'stock_low_v1');
    return [for (final row in r.requiredList('rows')) StockLowRow.fromJson(row)];
  }

  @override
  Future<ReplenishmentList> replenishment(String workspaceId, {String? siteId}) async {
    final answer = await _client.rpc<Object?>(
      'stock_replenishment_v1',
      params: {'p_workspace_id': workspaceId, 'p_site_id': siteId},
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
    final answer = await _client.rpc<Object?>(
      'create_replenishment_draft_v1',
      params: {
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
