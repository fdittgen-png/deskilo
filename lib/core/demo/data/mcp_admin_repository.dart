// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/auth/domain/second_factor.dart';
import '../../../features/mcp/domain/mcp_admin.dart';

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
        })
      >[];
  final decisions = <({String userId, String decisionId, bool approve})>[];
  final revoked = <String>[];
  PolicySaveStatus nextSave = PolicySaveStatus.saved;

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
  }) async {
    saves.add((
      expected: expectedRevision,
      mutationId: mutationId,
      enabled: enabled,
      operations: operations,
      ceiling: targetCeiling,
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
    );
    return PolicySaveResult(
      PolicySaveStatus.saved,
      revision: base.revision + 1,
    );
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
