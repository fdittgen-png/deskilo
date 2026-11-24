// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/till_offline.dart';

/// #4373 -- `counter_offline_sync_v1` and `counter_offline_list_v1` behind the port. A refusal of the whole call is thrown as the
/// server sent it; the refusal of one sale is in the answer.
class SupabaseCounterOffline implements TillOfflinePort {
  SupabaseCounterOffline(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(fn, params: params);
    } on PostgrestException catch (e, stack) {
      TraceLogger.instance.warn('money', 'the offline sales were refused: ${e.code}', stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<OfflineSyncAnswer> sync(String workspaceId, {required String sessionId, required DateTime offlineSince, required List<OfflineSale> sales, required int minorDigits}) async =>
      OfflineSyncAnswer.fromJson(await _call('counter_offline_sync_v1', {
        'p_workspace_id': workspaceId,
        'p_session_id': sessionId,
        'p_offline_since': offlineSince.toUtc().toIso8601String(),
        'p_sales': [for (final s in sales) s.toSyncJson(minorDigits: minorDigits)],
      }));

  @override
  Future<OfflineList> list(String workspaceId, {required String sessionId}) async =>
      OfflineList.fromJson(await _call('counter_offline_list_v1', {'p_workspace_id': workspaceId, 'p_session_id': sessionId}));
}
