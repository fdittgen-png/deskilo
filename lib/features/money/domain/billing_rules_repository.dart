// SPDX-License-Identifier: AGPL-3.0-or-later
import 'billing_rules.dart';
import 'workspace_status.dart';

/// #2591 — when the automatic invoice runs happen, the remembered
/// repartition rule, and the workspace status the repartition wizard reads.
abstract interface class BillingRulesRepository {
  /// #802 — when the two automatic invoice runs happen.
  Future<BillingRules> fetchBillingRules(String workspaceId);

  /// #934 — the workspace's status over [from]..[to] (YYYY-MM), admins
  /// and owners only (RPC `workspace_status`).
  Future<WorkspaceStatus> fetchWorkspaceStatus(
    String workspaceId,
    String from,
    String to,
  );

  /// #934 — the remembered repartition rule (`billing_rules.repartition`).
  Future<RepartitionRule> fetchRepartitionRule(String workspaceId);

  /// #934 — remember the rule the wizard was adjusted to.
  Future<void> setRepartitionRule(String workspaceId, RepartitionRule rule);

  /// Owner/admin only, server-enforced.
  Future<void> setBillingRules(String workspaceId, BillingRules rules);

  /// Runs both invoice runs for this workspace NOW instead of waiting for
  /// the nightly clock, and answers how many documents it raised.
  Future<int> sweepBillingInvoices(String workspaceId);
}
