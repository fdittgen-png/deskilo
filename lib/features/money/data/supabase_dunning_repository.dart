// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dunning.dart';
import '../domain/dunning_repository.dart';

/// #2591 — the dunning policy, its sweep and the holds, with its own client.
/// The bodies are the ones that lived in the money repository and its part
/// files.
class SupabaseDunningRepository implements DunningRepository {
  SupabaseDunningRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DunningRules> fetchDunningRules(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('dunning_rules')
        .eq('id', workspaceId)
        .single();
    return DunningRules.fromJson(
      row['dunning_rules'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<Map<String, String>> fetchDunningHolds(String workspaceId) async {
    final rows = await _client
        .from('invoice_dunning_holds')
        .select('invoice_id, reason')
        .eq('workspace_id', workspaceId)
        .isFilter('released_at', null);
    return {
      for (final row in rows)
        row['invoice_id'] as String: row['reason'] as String,
    };
  }

  @override
  Future<void> setDunningRules(String workspaceId, DunningRules rules) async {
    // #816 — see setBillingRules.
    await _client.rpc<void>(
      'set_dunning_rules',
      params: {'p_workspace_id': workspaceId, 'p_rules': rules.toJson()},
    );
  }

  @override
  Future<int> sweepPaymentReminders(String workspaceId) async {
    final n = await _client.rpc<Object?>(
      'sweep_payment_reminders',
      params: {'p_workspace_id': workspaceId},
    );
    return (n as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> placeDunningHold(
    String invoiceId, {
    required String reason,
    String note = '',
  }) => _client.rpc<void>(
    'place_dunning_hold',
    params: {'p_invoice_id': invoiceId, 'p_reason': reason, 'p_note': note},
  );

  @override
  Future<void> releaseDunningHold(String invoiceId) => _client.rpc<void>(
    'release_dunning_hold',
    params: {'p_invoice_id': invoiceId},
  );
}
