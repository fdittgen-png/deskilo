// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1626 — saving a workspace's MCP exposure. The workspace and the
// mutation id are fixed when the editor opens, so a retry replays the
// same save and a workspace switch can never retarget it; the expected
// revision is the one the owner looked at, so a concurrent change is a
// conflict to review, never an overwrite.
import '../../../core/ids/request_id.dart';
import '../../../core/mcp/mcp_operations.dart';
import '../domain/mcp_admin.dart';

/// How the policy screen groups operations: by the process they belong to.
enum McpOperationGroup { own, financial, membership, validations }

McpOperationGroup mcpOperationGroup(String op) {
  if (const {
    'list_pending_validations',
    'get_validation',
    'respond_to_validation',
  }.contains(op)) {
    return McpOperationGroup.validations;
  }
  return switch (mcpOperations[op]?.permission) {
    'issueInvoices' => McpOperationGroup.financial,
    'manageMembers' || 'manageBilling' => McpOperationGroup.membership,
    _ => McpOperationGroup.own,
  };
}

class McpPolicyDraft {
  McpPolicyDraft.from(McpPolicy base)
    : workspaceId = base.workspaceId,
      expectedRevision = base.revision,
      mutationId = newRequestId(),
      enabled = base.enabled,
      operations = {...base.operations},
      targetCeiling = base.targetCeiling;

  final String workspaceId;
  final int expectedRevision;
  final String mutationId;
  bool enabled;
  final Set<String> operations;
  String targetCeiling;

  /// Operations this save would add: assistants already connected do not
  /// get them until each person consents again (0276).
  Set<String> added(McpPolicy base) => operations.difference(base.operations);
}

class McpPolicyEditor {
  const McpPolicyEditor(this._repository);
  final McpAdminRepository _repository;

  Future<PolicySaveResult> save(McpPolicyDraft draft) => _repository.savePolicy(
    workspaceId: draft.workspaceId,
    expectedRevision: draft.expectedRevision,
    mutationId: draft.mutationId,
    enabled: draft.enabled && draft.operations.isNotEmpty,
    operations: draft.operations,
    targetCeiling: draft.targetCeiling,
  );
}
