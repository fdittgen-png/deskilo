// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../../../core/validation/pending_validation.dart';
import '../domain/command_receipt.dart';
import '../domain/invoice_action_commands.dart';

/// #2585 C2 — void and refund under a request id (0463). No retry: a lost
/// or undecodable answer is read back by the id, never sent again.
class SupabaseInvoiceActionCommands implements InvoiceActionCommands {
  SupabaseInvoiceActionCommands(this._client);

  final SupabaseClient _client;

  @override
  Future<void> voidInvoice(
    String invoiceId, {
    required String requestId,
    String reason = '',
  }) async {
    final answer = await _client.rpc<Object?>(
      'request_invoice_void_v1',
      params: {
        'p_invoice_id': invoiceId,
        'p_request_id': requestId,
        'p_reason': reason,
      },
    );
    applyOrPendingVoid(answer);
  }

  @override
  Future<void> settleCreditInvoice(
    String invoiceId, {
    required String requestId,
    String note = '',
  }) async {
    final answer = await _client.rpc<Object?>(
      'request_refund_v1',
      params: {
        'p_invoice_id': invoiceId,
        'p_request_id': requestId,
        'p_note': note,
      },
    );
    applyOrPendingVoid(answer);
  }

  @override
  Future<String> createInvoiceOnce(InvoiceIssueCommand command) async {
    final answer = await _client.rpc<Object?>(
      'create_invoice_receipted_v1',
      params: {
        'p_workspace_id': command.workspaceId,
        'p_member_id': command.memberId,
        'p_period': command.period,
        'p_request_id': command.requestId,
        'p_kind': command.kind.name,
      },
    );
    return _id(answer, 'create_invoice_receipted_v1');
  }

  @override
  Future<String> replaceInvoiceOnce(InvoiceIssueCommand command) async {
    final answer = await _client.rpc<Object?>(
      'create_invoice_replacement_v1',
      params: {
        'p_workspace_id': command.workspaceId,
        'p_member_id': command.memberId,
        'p_period': command.period,
        'p_replaces': command.replacesId,
        'p_request_id': command.requestId,
        'p_detailed': command.detailed,
        'p_kind': command.kind.name,
        'p_buyer_reference': command.buyerReference,
        'p_purchase_order': command.purchaseOrder,
        'p_correction_reason': command.correctionReason,
      },
    );
    return _id(answer, 'create_invoice_replacement_v1');
  }

  @override
  Future<String> settleInvoicesOnce({
    required String workspaceId,
    required String memberId,
    required List<String> invoiceIds,
    required String requestId,
    String note = '',
  }) async {
    final answer = await _client.rpc<Object?>(
      'settle_invoices_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_member_id': memberId,
        'p_invoice_ids': invoiceIds,
        'p_request_id': requestId,
        'p_note': note,
      },
    );
    return _id(answer, 'settle_invoices_v1');
  }

  /// The answer promises an id: anything else is a shape error (unknown
  /// outcome), never an empty id.
  String _id(Object? answer, String rpc) {
    if (answer is String && answer.isNotEmpty) return answer;
    throw JsonShapeException(rpc, 'id', 'non-empty String', '${answer.runtimeType}');
  }
}
