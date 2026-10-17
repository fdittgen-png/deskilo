// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../domain/purchase.dart';

/// The purchase documents and their RPCs (0461). The tables are read under
/// row level security (a member sees their own, a manager all); every write
/// goes through an RPC that derives actor, state and totals.
class SupabasePurchaseRepository implements PurchaseRepository {
  const SupabasePurchaseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PurchaseSummary>> fetchPurchases(String workspaceId) async {
    final rows = await _client
        .from('purchase_documents')
        .select(
          'id, kind, state, category, original_reference, currency, '
          'received_on, legacy_qualification, purchase_lines(gross_cents)',
        )
        .eq('workspace_id', workspaceId)
        .order('created_datetime', ascending: false);
    return [for (final r in rows) PurchaseSummary.fromRow(r)];
  }

  @override
  Future<PurchaseDetail> fetchDetail(
    String workspaceId,
    String purchaseId,
  ) async {
    final json = await _client.rpc<Object?>(
      'purchase_detail_v1',
      params: {'p_workspace_id': workspaceId, 'p_purchase_id': purchaseId},
    );
    return PurchaseDetail.fromJson(json);
  }

  @override
  Future<String> saveDraft(
    String workspaceId,
    String requestId,
    PurchaseBillDraft draft,
  ) async {
    final json = await _client.rpc<Object?>(
      'save_purchase_draft_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_expected_revision': draft.expectedRevision,
        'p_payload': draft.toPayload(),
      },
    );
    return JsonReader.of(
      json,
      context: 'save_purchase_draft_v1',
    ).string('purchase_id');
  }
}
