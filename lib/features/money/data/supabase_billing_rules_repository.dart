// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/billing_rules.dart';
import '../domain/billing_rules_repository.dart';
import '../domain/workspace_status.dart';

/// #2591 — the billing rules, the repartition rule and the workspace status,
/// with its own client. The bodies are the ones that lived in the money
/// repository and its part files.
class SupabaseBillingRulesRepository implements BillingRulesRepository {
  SupabaseBillingRulesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<BillingRules> fetchBillingRules(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('billing_rules')
        .eq('id', workspaceId)
        .single();
    return BillingRules.fromJson(
      row['billing_rules'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<WorkspaceStatus> fetchWorkspaceStatus(
    String workspaceId,
    String from,
    String to,
  ) async {
    final r = await _client.rpc<dynamic>(
      'workspace_status',
      params: {'p_workspace_id': workspaceId, 'p_from': from, 'p_to': to},
    );
    return WorkspaceStatus.fromJson(Map<String, dynamic>.from(r as Map));
  }

  @override
  Future<RepartitionRule> fetchRepartitionRule(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('billing_rules')
        .eq('id', workspaceId)
        .single();
    final rules = (row['billing_rules'] as Map?)?.cast<String, dynamic>();
    return RepartitionRule.fromJson(
      (rules?['repartition'] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  Future<void> setRepartitionRule(
    String workspaceId,
    RepartitionRule rule,
  ) async {
    await _client.rpc<dynamic>(
      'set_repartition_rule',
      params: {'p_workspace_id': workspaceId, 'p_rule': rule.toJson()},
    );
  }

  @override
  Future<void> setBillingRules(String workspaceId, BillingRules rules) async {
    // #816 — through the RPC gated on the `workspaceSettings` permission
    // (0144); the row's RLS was owner-only and ignored the matrix.
    await _client.rpc<void>(
      'set_billing_rules',
      params: {'p_workspace_id': workspaceId, 'p_rules': rules.toJson()},
    );
  }

  @override
  Future<int> sweepBillingInvoices(String workspaceId) async {
    final result = await _client.rpc<dynamic>(
      'sweep_billing_invoices',
      params: {'p_workspace_id': workspaceId},
    );
    return (result as num?)?.toInt() ?? 0;
  }
}
