// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/validation/pending_validation.dart';
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
}
