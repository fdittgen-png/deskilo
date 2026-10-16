// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/validation/pending_validation.dart';
import '../domain/billing_rules.dart';
import '../domain/invoice_commands.dart';

/// #2591 C3 — the invoice commands, with their own client. The bodies are
/// the ones that lived in the money repository's part files: the same RPCs,
/// the same pending/applied answers, no retry of a write.
class SupabaseInvoiceCommands implements InvoiceCommands {
  SupabaseInvoiceCommands(this._client);

  final SupabaseClient _client;

  @override
  Future<String> createInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
    String? replacesId,
    bool detailed = false,
    InvoiceKind kind = InvoiceKind.full,
    String buyerReference = '',
    String purchaseOrder = '',
    String correctionReason = '',
  }) async {
    // #982 — a replacement is a correction of a document of record and
    // issues directly; a new invoice goes through the policy, which
    // holds it (pending) or applies it at once.
    if (replacesId != null) {
      final id = await _client.rpc<dynamic>(
        'create_invoice',
        params: {
          'p_workspace_id': workspaceId,
          'p_member_id': memberId,
          'p_period': period,
          'p_replaces': replacesId,
          'p_detailed': detailed,
          'p_buyer_reference': buyerReference,
          'p_purchase_order': purchaseOrder,
          'p_kind': kind.name,
          'p_correction_reason': correctionReason,
        },
      );
      return id as String;
    }
    final answer = await _client.rpc<dynamic>(
      'request_invoice_issue',
      params: {
        'p_workspace_id': workspaceId,
        'p_member_id': memberId,
        'p_period': period,
        'p_kind': kind.name,
        'p_detailed': detailed,
        'p_allow_zero': false,
        'p_buyer_reference': buyerReference.isEmpty ? null : buyerReference,
        'p_purchase_order': purchaseOrder.isEmpty ? null : purchaseOrder,
      },
    );
    return applyOrPending(answer);
  }

  @override
  Future<void> voidInvoice(String invoiceId) async {
    await _client
        .rpc<dynamic>(
          'request_invoice_void',
          params: {'p_invoice_id': invoiceId},
        )
        .then(applyOrPendingVoid);
  }

  @override
  Future<void> remindInvoice(String invoiceId) async {
    await _client.rpc<void>(
      'record_invoice_reminder',
      params: {'p_invoice_id': invoiceId},
    );
  }

  @override
  Future<void> settleCreditInvoice(String invoiceId, {String note = ''}) async {
    // #982 — through the refund policy.
    final answer = await _client.rpc<dynamic>(
      'request_refund',
      params: {'p_invoice_id': invoiceId, 'p_note': note},
    );
    applyOrPendingVoid(answer);
  }

  @override
  Future<String> settleInvoices({
    required String workspaceId,
    required String memberId,
    required List<String> invoiceIds,
    String note = '',
  }) async {
    final id = await _client.rpc<dynamic>(
      'settle_invoices',
      params: {
        'p_workspace_id': workspaceId,
        'p_member_id': memberId,
        'p_invoice_ids': invoiceIds,
        'p_note': note,
      },
    );
    return id as String;
  }

  @override
  Future<void> matchInvoice({
    required String invoiceId,
    required String paymentLedgerId,
    required String resolution,
    String note = '',
  }) async {
    await _client.rpc<void>(
      'match_invoice',
      params: {
        'p_invoice_id': invoiceId,
        'p_payment_ledger_id': paymentLedgerId,
        'p_resolution': resolution,
        'p_note': note,
      },
    );
  }
}
