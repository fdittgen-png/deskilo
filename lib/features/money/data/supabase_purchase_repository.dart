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

  static const _payablePageSize = 100;
  static const _maxPayablePages = 20;

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

  /// Every page, newest first. A workspace's claims are few; the cap stops a
  /// server that never ends its cursor.
  @override
  Future<List<PayableRow>> fetchPayables(
    String workspaceId, {
    CreditorKind? kind,
  }) async {
    final rows = <PayableRow>[];
    String? afterCreated;
    String? afterId;
    for (var page = 0; page < _maxPayablePages; page++) {
      final json = await _client.rpc<Object?>(
        'purchase_payables_page_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_creditor_kind': ?kind?.wire,
          'p_limit': _payablePageSize,
          'p_after_created': ?afterCreated,
          'p_after_id': ?afterId,
        },
      );
      final r = JsonReader.of(json, context: 'purchase_payables_page_v1');
      rows.addAll([for (final o in r.list('rows')) PayableRow.fromJson(o)]);
      final next = r.objectOrNull('next');
      if (next == null) return rows;
      afterCreated = next.string('created');
      afterId = next.string('id');
    }
    return rows;
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
