// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/counter_till.dart';

/// #4366 -- `counter_readiness_v1`, `counter_receipt_draft_v1` and `counter_receipt_finalize_v1` behind the port.
/// A refusal is thrown as the server sent it (`knownRefusalText` reads its code); an answer of the wrong shape throws.
class SupabaseCounterTill implements TillPort {
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

  @override
  Future<TillReadiness> readiness(String workspaceId) async =>
      TillReadiness.fromJson(await _call('counter_readiness_v1', {'p_workspace_id': workspaceId}));

  @override
  Future<TillDraft> draft(String workspaceId, {required String requestId, required List<TillLine> lines, String? receiptId, int? expectedRevision}) async =>
      TillDraft.fromJson(await _call('counter_receipt_draft_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_receipt_id': receiptId,
        'p_expected_revision': expectedRevision,
        'p_body': {'lines': [for (final l in lines) l.toJson()]},
      }));

  @override
  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders}) async {
    final sold = await _call('counter_receipt_finalize_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_receipt_id': receiptId,
      'p_expected_revision': expectedRevision,
      'p_tenders': [for (final t in tenders) t.toJson()],
    });
    return TillSold.fromJson(sold, tracks: await _tracks(workspaceId, receiptId));
  }

  /// #4436 -- the track IDs the goods lines took, frozen when the stock moved (0939).
  Future<List<TillTrack>> _tracks(String workspaceId, String receiptId) async {
    final rows = await _client
        .from('counter_line_tracks')
        .select('line_id, track_kind, track_code, quantity')
        .eq('workspace_id', workspaceId)
        .eq('receipt_id', receiptId)
        .order('created_datetime');
    return [for (final row in rows) TillTrack.fromJson(row)];
  }
}
