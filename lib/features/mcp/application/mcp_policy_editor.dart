// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1626 — saving a workspace's MCP exposure. The workspace and the
// mutation id are fixed when the editor opens, so a retry replays the
// same save and a workspace switch can never retarget it; the expected
// revision is the one the owner looked at, so a concurrent change is a
// conflict to review, never an overwrite.
//
// #1625 — the draft also fixes the installation and account it was read
// from; the save goes there through that target's client. A retry of the
// unchanged draft keeps its id; a draft changed after a failed save is a
// new intent with a new id; a double tap joins the save in flight.
import '../../../core/ids/request_id.dart';
import '../../../core/mcp/mcp_operations.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_context.dart';
import 'mcp_commands.dart';

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

/// What one save sends, frozen when it is sent.
class McpPolicyPayload {
  McpPolicyPayload({
    required this.enabled,
    required Iterable<String> operations,
    required this.targetCeiling,
  }) : operations = List.unmodifiable(operations.toList()..sort());

  final bool enabled;
  final List<String> operations;
  final String targetCeiling;

  String get _signature => '$enabled|$targetCeiling|${operations.join(',')}';

  @override
  bool operator ==(Object other) =>
      other is McpPolicyPayload && other._signature == _signature;

  @override
  int get hashCode => _signature.hashCode;
}

class McpPolicyDraft {
  McpPolicyDraft.from(McpPolicy base)
    : workspaceId = base.workspaceId,
      context = base.context,
      expectedRevision = base.revision,
      _mutationId = newRequestId(),
      enabled = base.enabled,
      operations = {...base.operations},
      targetCeiling = base.targetCeiling;

  final String workspaceId;

  /// Where the base was read; null only for a policy read outside the
  /// registry, which cannot be saved.
  final McpContextRef? context;
  final int expectedRevision;
  String _mutationId;
  McpMutation<Object?>? _sent;
  bool enabled;
  final Set<String> operations;
  String targetCeiling;

  String get mutationId => _mutationId;

  /// Operations this save would add: assistants already connected do not
  /// get them until each person consents again (0276).
  Set<String> added(McpPolicy base) => operations.difference(base.operations);

  /// The intent to send now: the last one again when nothing changed.
  McpMutation<Object?> intent() {
    final scope = context;
    if (scope == null) throw McpTargetUnverified(workspaceId);
    final payload = McpPolicyPayload(
      enabled: enabled && operations.isNotEmpty,
      operations: operations,
      targetCeiling: targetCeiling,
    );
    final sent = _sent;
    if (sent != null && sent.payload == payload) return sent;
    if (sent != null) _mutationId = newRequestId();
    return _sent = McpMutation<Object?>(
      scope: scope,
      operation: 'save_mcp_policy',
      payload: payload,
      mutationId: _mutationId,
    );
  }
}

class McpPolicyEditor {
  const McpPolicyEditor(this._commands);
  final McpCommands _commands;

  Future<PolicySaveResult> save(McpPolicyDraft draft) {
    final expected = draft.expectedRevision;
    return _commands.execute(draft.intent(), (repositories, m) {
      final p = m.payload! as McpPolicyPayload;
      final ctx = m.scope as McpContextRef;
      return repositories.admin.savePolicy(
        workspaceId: ctx.workspaceId,
        expectedRevision: expected,
        mutationId: m.mutationId,
        enabled: p.enabled,
        operations: p.operations.toSet(),
        targetCeiling: p.targetCeiling,
      );
    });
  }
}
