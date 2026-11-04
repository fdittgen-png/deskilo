// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase orders over Supabase: read by RLS (managePurchases
// or viewFinances), written only through the RPCs of 0674.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/purchase_order.dart';

class SupabasePurchaseOrderRepository implements PurchaseOrderRepository {
  SupabasePurchaseOrderRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PurchaseOrder>> fetchOrders(String workspaceId) async {
    final rows = await _client
        .from('purchase_orders')
        .select('*, purchase_order_lines(*), suppliers(name)')
        .eq('workspace_id', workspaceId)
        .order('year', ascending: false)
        .order('number', ascending: false);
    return [for (final row in rows) PurchaseOrder.fromJson(row)];
  }

  PurchaseOrder _order(Object? json) => PurchaseOrder.fromJson(json);

  @override
  Future<PurchaseOrder> save(
    String workspaceId,
    String requestId,
    PurchaseOrderDraft draft,
  ) async => _order(
    await _client.rpc<Object?>(
      'save_purchase_order_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_expected_revision': draft.expectedRevision,
        'p_payload': draft.toPayload(),
      },
    ),
  );

  @override
  Future<PurchaseOrder> markSent(
    String workspaceId,
    String orderId,
    int revision,
    String requestId,
  ) async => _order(
    await _client.rpc<Object?>(
      'mark_purchase_order_sent_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_order_id': orderId,
        'p_revision': revision,
        'p_request_id': requestId,
      },
    ),
  );

  @override
  Future<PurchaseOrder> cancel(
    String workspaceId,
    String orderId,
    int revision,
    String reason,
    String requestId,
  ) async => _order(
    await _client.rpc<Object?>(
      'cancel_purchase_order_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_order_id': orderId,
        'p_revision': revision,
        'p_reason': reason,
        'p_request_id': requestId,
      },
    ),
  );
}
