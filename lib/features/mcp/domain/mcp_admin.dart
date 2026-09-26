// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1626 — a workspace owner's MCP exposure policy; #1627 — a database
// administrator's eligibility queue. Both are read and written through
// the server's own RPCs (0270/0271): the app never decides who may.

/// The owner's exposure policy for one workspace, as the server holds it.
class McpPolicy {
  const McpPolicy({
    required this.workspaceId,
    required this.revision,
    required this.enabled,
    required this.operations,
    required this.targetCeiling,
    required this.featureEnabled,
    required this.available,
  });

  final String workspaceId;
  final int revision;
  final bool enabled;
  final Set<String> operations;

  /// 'own' (a member's own records) or 'workspace'.
  final String targetCeiling;

  /// The workspace's `mcpAccess` flag: a policy cannot be switched on
  /// while it is off, but can always be narrowed or switched off.
  final bool featureEnabled;

  /// Every implemented operation, in the server's order.
  final List<String> available;

  factory McpPolicy.fromJson(Object? json) {
    final m = json is Map ? json : const <String, Object?>{};
    List<String> strings(Object? v) => [
      for (final x in (v is List ? v : const [])) '$x',
    ];
    return McpPolicy(
      workspaceId: '${m['workspace_id'] ?? ''}',
      revision: m['revision'] is int ? m['revision'] as int : 0,
      enabled: m['enabled'] == true,
      operations: strings(m['operations']).toSet(),
      targetCeiling: m['target_ceiling'] == 'workspace' ? 'workspace' : 'own',
      featureEnabled: m['feature_enabled'] == true,
      available: strings(m['available_operations']),
    );
  }
}

enum PolicySaveStatus { saved, replayed, stale, conflict }

class PolicySaveResult {
  const PolicySaveResult(this.status, {this.revision});
  final PolicySaveStatus status;
  final int? revision;

  factory PolicySaveResult.fromJson(Object? json) {
    final m = json is Map ? json : const <String, Object?>{};
    final revision = m['revision'] is int ? m['revision'] as int : null;
    return switch (m['status']) {
      'saved' => PolicySaveResult(PolicySaveStatus.saved, revision: revision),
      'replayed' => PolicySaveResult(
        PolicySaveStatus.replayed,
        revision: revision,
      ),
      'conflict' when m['reason'] == 'stale_revision' => PolicySaveResult(
        PolicySaveStatus.stale,
        revision: revision,
      ),
      _ => const PolicySaveResult(PolicySaveStatus.conflict),
    };
  }
}

/// One pending request for MCP eligibility on this database.
class EligibilityRequest {
  const EligibilityRequest({
    required this.requestId,
    required this.userId,
    required this.email,
    required this.revision,
    this.requestedAt,
  });

  final String requestId;
  final String userId;
  final String email;
  final int revision;
  final DateTime? requestedAt;

  static List<EligibilityRequest> listFromJson(Object? json) => [
    for (final r in json is List ? json : const [])
      if (r is Map && r['request_id'] is String && r['local_user_id'] is String)
        EligibilityRequest(
          requestId: r['request_id'] as String,
          userId: r['local_user_id'] as String,
          email: '${r['email'] ?? ''}',
          revision: r['revision'] is int ? r['revision'] as int : 0,
          requestedAt: DateTime.tryParse('${r['requested_at']}')?.toUtc(),
        ),
  ];
}

enum EligibilityDecisionStatus { decided, replayed, changed, refused }

EligibilityDecisionStatus eligibilityDecisionFromJson(Object? json) {
  final m = json is Map ? json : const <String, Object?>{};
  return switch (m['status']) {
    'approved' || 'rejected' || 'decided' => EligibilityDecisionStatus.decided,
    'replayed' => EligibilityDecisionStatus.replayed,
    'conflict' => EligibilityDecisionStatus.changed,
    _ => EligibilityDecisionStatus.refused,
  };
}

abstract interface class McpAdminRepository {
  Future<McpPolicy> policy(String workspaceId);

  Future<PolicySaveResult> savePolicy({
    required String workspaceId,
    required int expectedRevision,
    required String mutationId,
    required bool enabled,
    required Set<String> operations,
    required String targetCeiling,
  });

  Future<List<EligibilityRequest>> eligibilityRequests();

  Future<EligibilityDecisionStatus> decide({
    required EligibilityRequest request,
    required String decisionId,
    required bool approve,
  });

  /// Blocks this person's MCP use across this database's workspaces.
  Future<bool> revokeEligibility(String userId);
}
