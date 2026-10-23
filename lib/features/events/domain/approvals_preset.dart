// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The approvals preset of the setup guide: one default rule for every
// request without a rule of its own, decided by the owner and the
// administrators, of whom [requiredCount] must accept. The people who can
// decide are counted the way the server counts them when it calls a rule
// short (`workspace_readiness`, 0399): every active member who is an owner
// or an administrator, once. A rule above that number would hold its
// requests forever, so it is never written.
import 'validation_policy.dart';

/// Who can decide under the preset.
class ApprovalsPreset {
  const ApprovalsPreset({required this.owners, required this.admins});

  /// Active owners.
  final int owners;

  /// Active administrators who are not owners.
  final int admins;

  int get people => owners + admins;

  /// Whether [requiredCount] approvals can ever be gathered.
  bool reachable(int requiredCount) =>
      requiredCount >= 1 && requiredCount <= people;

  /// The default rule [stored] becomes: owners and every administrator
  /// decide, [requiredCount] of them accept, and nothing else about the
  /// stored rule changes. Without a stored rule it starts from the
  /// built-in one.
  ValidationPolicy defaultRule(
    String workspaceId,
    ValidationPolicy? stored,
    int requiredCount,
  ) => (stored ?? ValidationPolicy.defaults(workspaceId, null)).copyWith(
    requiredCount: requiredCount,
    adminsMayValidate: true,
    eligibleAdminIds: const [],
    validatorScope: 'admins',
    ownerRequired: false,
  );
}
