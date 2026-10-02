// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/auth/domain/second_factor.dart';
import '../../../features/mcp/domain/mcp_admin.dart';
import '../../../features/mcp/domain/mcp_usage.dart';

/// #1626/#1627 — in-memory policy and eligibility queue for tests and
/// Demo (where MCP stays off: the feature is off and nobody is eligible).
class FakeMcpAdminRepository implements McpAdminRepository {
  FakeMcpAdminRepository({
    McpPolicy? policy,
    List<EligibilityRequest>? requests,
  }) : current = policy,
       queue = requests ?? [];

  McpPolicy? current;
  final List<EligibilityRequest> queue;
  final saves =
      <
        ({
          int expected,
          String mutationId,
          bool enabled,
          Set<String> operations,
          String ceiling,
          Set<String> optionalFields,
        })
      >[];
  final decisions = <({String userId, String decisionId, bool approve})>[];
  final revoked = <String>[];
  PolicySaveStatus nextSave = PolicySaveStatus.saved;

  /// #1809 — the installation maximum; Demo offers no optional field.
  McpDisclosureMaximum maximum = const McpDisclosureMaximum(
    fields: {},
    available: [],
  );
  final maximumSaves = <Set<String>>[];

  /// #1630 — the workspace's usage rows; Demo has none, so it shows zeros.
  List<({DateTime? day, String operation, McpUsageCounts counts})> usage = [];

  @override
  Future<McpPolicy> policy(String workspaceId) async =>
      current ??
      McpPolicy(
        workspaceId: workspaceId,
        revision: 0,
        enabled: false,
        operations: const {},
        targetCeiling: 'own',
        featureEnabled: false,
        available: const [],
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
  }) async {
    saves.add((
      expected: expectedRevision,
      mutationId: mutationId,
      enabled: enabled,
      operations: operations,
      ceiling: targetCeiling,
      optionalFields: optionalFields,
    ));
    final base = await policy(workspaceId);
    if (nextSave == PolicySaveStatus.stale) {
      return PolicySaveResult(
        PolicySaveStatus.stale,
        revision: base.revision + 1,
      );
    }
    current = McpPolicy(
      workspaceId: workspaceId,
      revision: base.revision + 1,
      enabled: enabled,
      operations: operations,
      targetCeiling: targetCeiling,
      featureEnabled: base.featureEnabled,
      available: base.available,
      optionalFields: optionalFields,
      availableOptionalFields: base.availableOptionalFields,
    );
    return PolicySaveResult(
      PolicySaveStatus.saved,
      revision: base.revision + 1,
    );
  }

  @override
  Future<McpDisclosureMaximum> disclosureMaximum() async => maximum;

  @override
  Future<Set<String>?> setDisclosureMaximum(Set<String> fields) async {
    maximumSaves.add(fields);
    maximum = McpDisclosureMaximum(
      fields: fields,
      available: maximum.available,
    );
    return fields;
  }

  @override
  Future<List<EligibilityRequest>> eligibilityRequests() async =>
      List.of(queue);

  @override
  Future<EligibilityDecisionStatus> decide({
    required EligibilityRequest request,
    required String decisionId,
    required bool approve,
  }) async {
    decisions.add((
      userId: request.userId,
      decisionId: decisionId,
      approve: approve,
    ));
    queue.removeWhere((r) => r.requestId == request.requestId);
    return EligibilityDecisionStatus.decided;
  }

  @override
  Future<bool> revokeEligibility(String userId) async {
    revoked.add(userId);
    return true;
  }

  @override
  Future<McpWorkspaceUsage> workspaceUsage(String workspaceId) async =>
      McpWorkspaceUsage(workspaceId: workspaceId, rows: List.of(usage));

  /// #1827 B — the instance console; null = not the instance operator.
  InstanceMcpOverview? instance;
  final instanceCalls = <String>[];

  @override
  Future<InstanceMcpOverview?> instanceOverview() async => instance;

  @override
  Future<void> grantAdministrator(String userId, {bool canProvision = true}) async =>
      instanceCalls.add('grant:$userId');

  @override
  Future<void> revokeAdministrator(String userId) async =>
      instanceCalls.add('revoke:$userId');

  @override
  Future<void> setClient(String clientId, {required bool active}) async =>
      instanceCalls.add('client:$clientId:$active');

  @override
  Future<void> setRuntime({required bool enabled}) async =>
      instanceCalls.add('runtime:$enabled');
}

/// A second factor that is exactly what the test says: never aal2 by
/// default, and a code verifies only when it equals [validCode].
class FakeSecondFactorRepository implements SecondFactorRepository {
  FakeSecondFactorRepository({
    this.aal2 = false,
    this.verifiedTotpId,
    this.validCode = '123456',
  });
  bool aal2;
  String? verifiedTotpId;
  final String validCode;
  int enrollments = 0;

  @override
  Future<SecondFactorState> state() async =>
      SecondFactorState(aal2: aal2, verifiedTotpId: verifiedTotpId);

  @override
  Future<TotpEnrollment> enrollTotp() async {
    enrollments++;
    return const TotpEnrollment(
      factorId: 'factor-1',
      secret: 'JBSWY3DPEHPK3PXP',
      uri: 'otpauth://totp/Deskilo:test?secret=JBSWY3DPEHPK3PXP',
    );
  }

  @override
  Future<void> verify(String factorId, String code) async {
    if (code != validCode) throw StateError('invalid code');
    aal2 = true;
    verifiedTotpId = factorId;
  }
}
