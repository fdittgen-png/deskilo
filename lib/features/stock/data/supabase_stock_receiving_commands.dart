// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stock_receiving.dart';
import 'stock_rpc.dart';

/// #4171 (A) -- `put_away_receipt_v1` and `record_receipt_and_put_away_v1`
/// behind the port, and the allocation read. A refusal of the server becomes
/// the typed failure the screen shows under its field; a request id that is
/// retried answers the same ids and says so.
class SupabaseStockReceivingCommands implements StockReceivingCommands {
  SupabaseStockReceivingCommands(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ReceiptAllocation>> allocations(String workspaceId, String receiptId) async {
    final rows = await StockRpc(_client).rows('stock_receipt_allocations', _client
        .from('stock_receipt_allocations')
        .select(
          'id, receipt_line_id, item_id, variant_id, lot_id, location_id, movement_id, '
          'entered_unit, entered_quantity, inventory_quantity, order_reference, supplier_name, line_text',
        )
        .eq('workspace_id', workspaceId)
        .eq('receipt_id', receiptId)
        .order('part'));
    return [for (final row in rows) ReceiptAllocation.fromJson(row)];
  }

  @override
  Future<List<ReceiptAllocation>> allocationsOfOrder(String workspaceId, String orderId) async {
    final rows = await StockRpc(_client).rows('stock_receipt_allocations', _client
        .from('stock_receipt_allocations')
        .select(
          'id, receipt_line_id, item_id, variant_id, lot_id, location_id, movement_id, '
          'entered_unit, entered_quantity, inventory_quantity, order_reference, supplier_name, line_text, '
          'purchase_order_lines(line_no), purchase_order_receipts!inner(order_id)',
        )
        .eq('workspace_id', workspaceId)
        .eq('purchase_order_receipts.order_id', orderId)
        .order('created_datetime'));
    return [for (final row in rows) ReceiptAllocation.fromJson(row)];
  }

  @override
  Future<PutAwayResult> putAway(
    String workspaceId,
    String receiptId,
    List<PutAwayAllocation> allocations,
    String requestId,
  ) => _call('put_away_receipt_v1', {
    'p_workspace_id': workspaceId,
    'p_receipt_id': receiptId,
    'p_request_id': requestId,
    'p_allocations': [for (final a in allocations) a.toJson()],
  });

  @override
  Future<PutAwayResult> recordAndPutAway(
    String workspaceId,
    DeliveryDraft delivery,
    List<PutAwayAllocation> allocations,
    String requestId,
  ) => _call('record_receipt_and_put_away_v1', {
    'p_workspace_id': workspaceId,
    'p_order_id': delivery.orderId,
    'p_revision': delivery.orderRevision,
    'p_received_on': delivery.receivedOn,
    'p_lines': [
      for (final l in delivery.lines) {'line_no': l.lineNo, 'quantity': l.quantity},
    ],
    'p_note': delivery.note,
    'p_request_id': requestId,
    'p_allocations': [for (final a in allocations) a.toJson()],
  });

  Future<PutAwayResult> _call(String rpc, Map<String, Object?> params) async {
    // the put-away names pieces: a refused piece (DKG25, DKG26) is typed with the piece it names (#4379)
    return StockRpc(_client).guard('a stock command', pieces: true, () async {
      final answer = await _client.rpc<Object?>(rpc, params: params);
      final r = JsonReader.of(answer, context: rpc);
      return (
        receiptId: r.string('receipt_id'),
        replayed: r.boolOr('replayed', fallback: false),
        allocations: [for (final a in r.list('allocations')) ReceiptAllocation.fromJson(a)],
      );
    });
  }
}
