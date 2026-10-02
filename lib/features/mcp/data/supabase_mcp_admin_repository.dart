// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/schema_version.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_usage.dart';

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
    required Set<String> optionalFields,
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
        'p_optional_fields': (optionalFields.toList()..sort()),
      },
    ),
  );

  @override
  Future<McpDisclosureMaximum> disclosureMaximum() async =>
      McpDisclosureMaximum.fromJson(
        await _client.rpc<Object?>('mcp_disclosure_status'),
      );

  @override
  Future<Set<String>?> setDisclosureMaximum(Set<String> fields) async {
    final r = await _client.rpc<Object?>(
      'set_mcp_disclosure_maximum',
      params: {'p_fields': (fields.toList()..sort())},
    );
    if (r is! Map || r['status'] != 'saved') return null;
    return mcpKnownOptionalFields(r['optional_fields']).toSet();
  }

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

  @override
  Future<McpWorkspaceUsage> workspaceUsage(String workspaceId) async =>
      McpWorkspaceUsage.fromJson(
        await _client.rpc<Object?>(
          'mcp_usage_summary_workspace',
          params: {'p_workspace_id': workspaceId},
        ),
      );

  @override
  Future<InstanceMcpOverview?> instanceOverview() async {
    try {
      final json = await _client.rpc<Object?>('instance_mcp_overview');
      return json is Map
          ? InstanceMcpOverview.fromJson(Map<String, dynamic>.from(json))
          : null;
    } on PostgrestException catch (e, st) {
      // Not the instance operator, or a server before 0339: no console.
      if (isMissingFunction(e) || e.message.contains('instance operator')) {
        TraceLogger.instance.warn('mcp', 'no instance console here',
            error: e, stackTrace: st);
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> grantAdministrator(String userId, {bool canProvision = true}) =>
      _client.rpc<Object?>('instance_grant_database_admin', params: {
        'p_target': userId,
        'p_can_provision': canProvision,
      });

  @override
  Future<void> revokeAdministrator(String userId) => _client.rpc<Object?>(
      'instance_revoke_database_admin', params: {'p_target': userId});

  @override
  Future<void> setClient(String clientId, {required bool active}) =>
      _client.rpc<Object?>('instance_set_mcp_client', params: {
        'p_client_id': clientId,
        'p_active': active,
      });

  @override
  Future<void> setRuntime({required bool enabled}) =>
      _client.rpc<Object?>('instance_set_mcp_runtime', params: {
        'p_enabled': enabled,
      });
}
