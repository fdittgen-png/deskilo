// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1626 — a workspace owner's MCP exposure policy; #1627 — a database
// administrator's eligibility queue. Both are read and written through
// the server's own RPCs (0270/0271): the app never decides who may.
export 'instance_operator.dart';
import 'instance_operator.dart';
import '../../../core/mcp/mcp_operations.dart';
import 'mcp_context.dart';
import 'mcp_usage.dart';

/// #1809 — a server list of optional fields, kept to the ones the
/// contract defines ([mcpOptionalFields]) and in the contract's order.
List<String> mcpKnownOptionalFields(Object? json) {
  final named = {for (final x in (json is List ? json : const [])) '$x'};
  return [
    for (final f in mcpOptionalFields)
      if (named.contains(f)) f,
  ];
}

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
    this.optionalFields = const {},
    this.availableOptionalFields = const [],
    this.context,
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

  /// #1809 — the optional fields this workspace allows assistants to see.
  final Set<String> optionalFields;

  /// #1809 — the installation maximum: the owner chooses within it.
  final List<String> availableOptionalFields;

  /// #1625 — the context it was read for; a draft saves back there.
  final McpContextRef? context;

  McpPolicy withContext(McpContextRef context) => McpPolicy(
    workspaceId: workspaceId,
    revision: revision,
    enabled: enabled,
    operations: operations,
    targetCeiling: targetCeiling,
    featureEnabled: featureEnabled,
    available: available,
    optionalFields: optionalFields,
    availableOptionalFields: availableOptionalFields,
    context: context,
  );

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
      optionalFields: mcpKnownOptionalFields(m['optional_fields']).toSet(),
      availableOptionalFields: mcpKnownOptionalFields(
        m['available_optional_fields'],
      ),
    );
  }
}

/// #1809 — the installation maximum of optional fields, as a database
/// administrator sees it (require_database_reviewer: aal2).
class McpDisclosureMaximum {
  const McpDisclosureMaximum({required this.fields, required this.available});

  /// The fields this database lets owners offer.
  final Set<String> fields;

  /// Every field the contract lets a person disclose.
  final List<String> available;

  factory McpDisclosureMaximum.fromJson(Object? json) {
    final m = json is Map ? json : const <String, Object?>{};
    return McpDisclosureMaximum(
      fields: mcpKnownOptionalFields(m['optional_fields']).toSet(),
      available: mcpKnownOptionalFields(m['available_fields']),
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
    this.scope,
  });

  final String requestId;
  final String userId;
  final String email;
  final int revision;
  final DateTime? requestedAt;

  /// #1625 — the installation whose queue it came from; decided there.
  final McpInstanceRef? scope;

  EligibilityRequest withScope(McpInstanceRef scope) => EligibilityRequest(
    requestId: requestId,
    userId: userId,
    email: email,
    revision: revision,
    requestedAt: requestedAt,
    scope: scope,
  );

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

enum EligibilityDecisionStatus {
  decided,
  replayed,
  changed,
  refused,

  /// #1625 — the TARGET's session is not at aal2: nothing was sent. A
  /// second factor on another installation (the active one) never counts.
  secondFactorRequired,
}

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
    required Set<String> optionalFields,
  });

  /// #1809 — the installation maximum (a database administrator, aal2).
  Future<McpDisclosureMaximum> disclosureMaximum();

  /// Saves the installation maximum; answers the fields the server kept,
  /// or null when it refused.
  Future<Set<String>?> setDisclosureMaximum(Set<String> fields);

  Future<List<EligibilityRequest>> eligibilityRequests();

  Future<EligibilityDecisionStatus> decide({
    required EligibilityRequest request,
    required String decisionId,
    required bool approve,
  });

  /// Blocks this person's MCP use across this database's workspaces.
  Future<bool> revokeEligibility(String userId);

  /// #1630 — the workspace's assistant usage over 30 days, counts only
  /// (the owner or a database administrator).
  Future<McpWorkspaceUsage> workspaceUsage(String workspaceId);

  /// #1827 B — the installation's assistants as the instance operator
  /// sees them; null when the caller is not the instance operator.
  Future<InstanceMcpOverview?> instanceOverview();

  /// #1827 B — instance operator, second factor: database administrators,
  /// assistant clients and the installation-wide runtime switch.
  Future<void> grantAdministrator(String userId, {bool canProvision = true});
  Future<void> revokeAdministrator(String userId);
  Future<void> setClient(String clientId, {required bool active});
  Future<void> setRuntime({required bool enabled});
}
