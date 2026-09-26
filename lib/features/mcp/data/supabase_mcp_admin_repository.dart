// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/mcp_admin.dart';

/// #1626/#1627 — the owner policy RPCs (0271) and the eligibility review
/// RPCs (0270). The server checks ownership, administrator status and
/// the second factor on every call.
class SupabaseMcpAdminRepository implements McpAdminRepository {
  const SupabaseMcpAdminRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<McpPolicy> policy(String workspaceId) async => McpPolicy.fromJson(
    await _client.rpc<Object?>(
      'mcp_policy_status',
      params: {'p_workspace_id': workspaceId},
    ),
  );

  @override
  Future<PolicySaveResult> savePolicy({
    required String workspaceId,
    required int expectedRevision,
    required String mutationId,
    required bool enabled,
    required Set<String> operations,
    required String targetCeiling,
  }) async => PolicySaveResult.fromJson(
    await _client.rpc<Object?>(
      'save_mcp_policy',
      params: {
        'p_workspace_id': workspaceId,
        'p_expected_revision': expectedRevision,
        'p_mutation_id': mutationId,
        'p_enabled': enabled,
        'p_operations': (operations.toList()..sort()),
        'p_target_ceiling': targetCeiling,
      },
    ),
  );

  @override
  Future<List<EligibilityRequest>> eligibilityRequests() async =>
      EligibilityRequest.listFromJson(
        await _client.rpc<Object?>('list_mcp_eligibility_requests'),
      );

  @override
  Future<EligibilityDecisionStatus> decide({
    required EligibilityRequest request,
    required String decisionId,
    required bool approve,
  }) async => eligibilityDecisionFromJson(
    await _client.rpc<Object?>(
      'decide_mcp_eligibility',
      params: {
        'p_subject': request.userId,
        'p_decision_id': decisionId,
        'p_approve': approve,
        'p_expected_revision': request.revision,
      },
    ),
  );

  @override
  Future<bool> revokeEligibility(String userId) async {
    final r = await _client.rpc<Object?>(
      'revoke_mcp_eligibility',
      params: {'p_subject': userId},
    );
    return r is Map && r['status'] == 'revoked';
  }
}
