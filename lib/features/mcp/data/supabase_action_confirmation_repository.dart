// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/schema_version.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/action_confirmation.dart';

/// #1619 — `mcp_get_action_confirmation` and `mcp_confirm_action`, called
/// from the app's own session. A server without them answers unavailable.
class SupabaseActionConfirmationRepository implements ActionConfirmationRepository {
  const SupabaseActionConfirmationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ActionConfirmation> get(String id) async {
    try {
      return ActionConfirmation.fromJson(
          id,
          await _client.rpc<Object?>('mcp_get_action_confirmation',
              params: {'p_confirmation_id': id}));
    } on PostgrestException catch (e, st) {
      if (!isMissingFunction(e)) rethrow;
      TraceLogger.instance.warn('mcp', 'confirmations are absent on this server',
          error: e, stackTrace: st);
      return ActionConfirmation(id: id, status: ConfirmationStatus.unavailable);
    }
  }

  @override
  Future<ConfirmationStatus> respond(String id, {required bool accept}) async {
    final answer = await _client.rpc<Object?>('mcp_confirm_action',
        params: {'p_confirmation_id': id, 'p_accept': accept});
    return ConfirmationStatus.fromWire(answer is Map ? answer['status'] : null);
  }
}
