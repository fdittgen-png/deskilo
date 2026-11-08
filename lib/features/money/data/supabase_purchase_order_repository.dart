// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase orders over Supabase: read by RLS (managePurchases
// or viewFinances), written only through the RPCs of 0681, 0683 and 0684.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/purchase_order.dart';
import '../domain/purchase_order_receipt.dart';

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

  @override
  Future<List<PurchaseOrderSend>> fetchSends(String workspaceId) async {
    final rows = await _client
        .from('purchase_order_sends')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_datetime', ascending: false);
    return [for (final row in rows) PurchaseOrderSend.fromJson(row)];
  }

  @override
  Future<PurchaseOrderMailSettings?> fetchMailSettings(
    String workspaceId,
  ) async {
    final row = await _client
        .from('purchase_order_mail_settings')
        .select('sender_email, sender_name, has_api_key, revision')
        .eq('workspace_id', workspaceId)
        .maybeSingle();
    return row == null ? null : PurchaseOrderMailSettings.fromJson(row);
  }

  @override
  Future<PurchaseOrderMailSettings> saveMailSettings(
    String workspaceId,
    PurchaseOrderMailDraft draft,
  ) async => PurchaseOrderMailSettings.fromJson(
    await _client.rpc<Object?>(
      'save_purchase_order_mail_settings_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_sender_email': draft.senderEmail.trim(),
        'p_sender_name': draft.senderName.trim(),
        // Empty keeps the stored key; the answer never carries one.
        'p_api_key': draft.apiKey.trim().isEmpty ? null : draft.apiKey.trim(),
        'p_revision': draft.revision,
      },
    ),
  );

  @override
  Future<PurchaseOrderSend> sendByEmail(
    String workspaceId,
    PurchaseOrder order,
    String attemptId,
    PurchaseOrderMail mail,
  ) async {
    final response = await _client.functions.invoke(
      'send-purchase-order',
      body: {
        'workspace_id': workspaceId,
        'order_id': order.id,
        'revision': order.revision,
        'attempt_id': attemptId,
        'subject': mail.subject,
        'text': mail.text,
        'pdf_base64': mail.pdfBase64,
        'file_name': mail.fileName,
      },
    );
    return PurchaseOrderSend.fromJson(response.data);
  }

  @override
  Future<PurchaseOrderSend> resolveSend(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  }) async => PurchaseOrderSend.fromJson(
    await _client.rpc<Object?>(
      'resolve_purchase_order_send_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_attempt_id': attemptId,
        'p_delivered': delivered,
      },
    ),
  );

  @override
  Future<List<PurchaseOrderReceipt>> fetchReceipts(String workspaceId) async {
    final rows = await _client
        .from('purchase_order_receipts')
        .select(
          'id, order_id, received_on, note, '
          'purchase_order_receipt_lines(quantity, purchase_order_lines(line_no))',
        )
        .eq('workspace_id', workspaceId)
        .order('received_on', ascending: false)
        .order('created_datetime', ascending: false);
    return [for (final row in rows) PurchaseOrderReceipt.fromJson(row)];
  }

  @override
  Future<PurchaseOrder> recordReceipt(
    String workspaceId,
    String requestId,
    PurchaseOrderReceiptDraft draft,
  ) async => _order(
    await _client.rpc<Object?>(
      'record_purchase_order_receipt_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_order_id': draft.order.id,
        'p_revision': draft.order.revision,
        'p_received_on': isoDay(draft.receivedOn),
        'p_lines': draft.toLines(),
        'p_note': draft.note.trim(),
        'p_request_id': requestId,
      },
    ),
  );

  @override
  Future<void> linkBill(
    String workspaceId,
    String purchaseId,
    String? orderId,
  ) async {
    await _client.rpc<Object?>(
      'link_purchase_to_order_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_purchase_id': purchaseId,
        'p_order_id': orderId,
      },
    );
  }
}
