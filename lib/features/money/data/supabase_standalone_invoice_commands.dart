// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (A2) -- the standalone invoice commands over the server's RPCs
// (`save_standalone_invoice_draft_v1`, `preview_standalone_invoice_v1`,
// `issue_standalone_invoice_v1`, 0820). A write is never retried here: a lost
// answer is looked up by its request id.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/previewed_document.dart';
import '../domain/standalone_invoice.dart';

class SupabaseStandaloneInvoiceCommands implements StandaloneInvoiceCommands {
  SupabaseStandaloneInvoiceCommands(this._client);

  final SupabaseClient _client;

  @override
  Future<StandaloneSaved> saveDraft({
    required String workspaceId,
    required StandaloneDraft draft,
  }) async => StandaloneSaved.fromJson(
    await _client.rpc<Object?>(
      'save_standalone_invoice_draft_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_draft_id': draft.draftId,
        'p_expected_revision': draft.revision,
        'p_subject': draft.subjectMemberId,
        'p_service_date': draft.serviceDay,
        'p_due_on': draft.dueDay,
        'p_buyer_reference': draft.buyerReference,
        'p_purchase_order': draft.purchaseOrder,
        'p_lines': draft.linesWire(),
      },
    ),
  );

  @override
  Future<PreviewedDocument> preview({
    required String workspaceId,
    required String draftId,
    required int revision,
  }) async => PreviewedDocument.fromJson(
    await _client.rpc<Object?>(
      'preview_standalone_invoice_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_draft_id': draftId,
        'p_revision': revision,
      },
    ),
  );

  @override
  Future<StandaloneIssued> issue({
    required String workspaceId,
    required String draftId,
    required int revision,
    required String requestId,
  }) async => StandaloneIssued.fromJson(
    await _client.rpc<Object?>(
      'issue_standalone_invoice_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_draft_id': draftId,
        'p_revision': revision,
        'p_request_id': requestId,
      },
    ),
  );
}
