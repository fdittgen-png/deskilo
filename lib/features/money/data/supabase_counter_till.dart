// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/counter_receipt_document.dart';
import '../domain/counter_till.dart';

/// #4366 -- `counter_readiness_v1`, `counter_receipt_draft_v1` and `counter_receipt_finalize_v1` behind the port; #4185 the
/// card authorization asked of the terminal and its answer (`counter_tender_request_v1`, `counter_tender_resolve_v1`).
/// A refusal is thrown as the server sent it (`knownRefusalText` reads its code); an answer of the wrong shape throws.
/// The table of the counter's receipts, read by this file and by the counter's book.
const String counterReceiptsTable = 'counter_receipts';

class SupabaseCounterTill implements TillPort, TillCopyPort, TillLotsPort {
  SupabaseCounterTill(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(fn, params: params);
    } on PostgrestException catch (e, stack) {
      TraceLogger.instance.warn('money', 'the till was refused: ${e.code}', stackTrace: stack);
      rethrow;
    }
  }

  /// #4184 -- the readiness, each operation with the evidence its registry row names (`counter_country_operations`,
  /// reference data every signed-in person may read). Evidence that cannot be read leaves the operation as the server
  /// answered it: the outcome is the server's either way.
  @override
  Future<TillReadiness> readiness(String workspaceId) async {
    final readiness = TillReadiness.fromJson(await _call('counter_readiness_v1', {'p_workspace_id': workspaceId}));
    if (readiness.operations.isEmpty) return readiness;
    final Map<String, String> evidence;
    try {
      final rows = await fetchConfigurationList(
        table: 'counter_country_operations',
        build: () => _client
            .from('counter_country_operations')
            .select('operation, evidence')
            .eq('country_code', readiness.country)
            .eq('regime', readiness.fiscalObligation)
            .order('operation', ascending: true),
      );
      evidence = {for (final row in rows) '${row['operation']}': '${row['evidence'] ?? ''}'};
    } on Object catch (e, stack) {
      TraceLogger.instance.warn('money', 'the counter evidence was not read', error: e, stackTrace: stack);
      return readiness;
    }
    return TillReadiness(
      country: readiness.country,
      fiscalObligation: readiness.fiscalObligation,
      ready: readiness.ready,
      operations: [for (final o in readiness.operations) o.withEvidence(evidence[o.operation] ?? '')],
    );
  }

  /// #4184 -- the frozen document of a finalized receipt, read through the versioned reader (a receipt of another
  /// version is refused, never guessed).
  @override
  Future<int> copy(String workspaceId, {required String requestId, required String receiptId}) async => tillCopyNumberOf(
    await _call('counter_receipt_copy_v1', {'p_workspace_id': workspaceId, 'p_request_id': requestId, 'p_receipt_id': receiptId}),
  );

  @override
  Future<List<TillLot>> lots(String workspaceId, String itemId) async =>
      tillLotsOf(await _call('counter_item_lots_v1', {'p_workspace_id': workspaceId, 'p_item_id': itemId}));

  @override
  Future<CounterReceiptDocument> receipt(String workspaceId, String receiptId) async {
    final row = await _client
        .from(counterReceiptsTable)
        .select('frozen')
        .eq('workspace_id', workspaceId)
        .eq('id', receiptId)
        .eq('state', 'finalized')
        .single();
    return CounterReceiptDocument.decode(row['frozen']);
  }

  @override
  Future<TillDraft> draft(String workspaceId, {required String requestId, required List<TillLine> lines, String? receiptId, int? expectedRevision, String? tillId}) async =>
      TillDraft.fromJson(await _call('counter_receipt_draft_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_receipt_id': receiptId,
        'p_expected_revision': expectedRevision,
        'p_body': {'lines': [for (final l in lines) l.toJson()], 'till_id': ?tillId},
      }));

  @override
  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders}) async =>
      TillSold.fromJson(await _call('counter_receipt_finalize_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_receipt_id': receiptId,
        'p_expected_revision': expectedRevision,
        'p_tenders': [for (final t in tenders) t.toJson()],
      }));

  @override
  Future<TillCardAsked> requestCard(String workspaceId, {required String requestId, required String receiptId, required int amountMinor}) async =>
      TillCardAsked.fromJson(await _call('counter_tender_request_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_receipt_id': receiptId,
        'p_kind': 'card',
        'p_amount_minor': amountMinor,
      }));

  @override
  Future<({String state, String? reconciliation})> resolveCard(String workspaceId, {required String requestId, required String tenderId, required String outcome, String providerRef = ''}) async {
    final out = Map<String, Object?>.from(await _call('counter_tender_resolve_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_tender_id': tenderId,
      'p_outcome': outcome,
      'p_provider_ref': providerRef,
    }) as Map);
    return (state: '${out['state'] ?? outcome}', reconciliation: out['reconciliation'] as String?);
  }
}
