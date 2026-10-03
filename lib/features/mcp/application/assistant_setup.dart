// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1827 — the guided assistant setup: the steps that make assistants work
// for one workspace, each with its state, who takes it and whether the
// person looking may. Every state is read from the server's answers (the
// same five reads as McpAccessStatus, plus the workspace's mcpAccess flag
// and the caller's permissions); nothing here is assumed, and a missing
// answer is `unavailable`, never `done`.
//
// The installation-wide steps (first administrator, approving a client,
// switching the runtime on) belong to the instance owner and their
// delegates (#1829), never to a workspace role; this checklist only shows
// whether they are done and who does them.
import '../../../core/mcp/mcp_operations.dart';
import '../../../core/mcp/mcp_spec.dart';
import '../../auth/domain/identity_binding.dart';
import '../domain/mcp_access_status.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_connection.dart';
import 'mcp_policy_editor.dart';

/// In the order each depends on the one before.
enum AssistantSetupStep {
  /// The person links their account to this database's identity.
  identity,

  /// Someone with manageIntegrations turns `mcpAccess` on (0360
  /// `set_workspace_mcp_access`): each workspace for itself.
  workspace,

  /// Someone with manageIntegrations chooses what assistants may do.
  policy,

  /// The person asks this database's administrators; one of them decides.
  eligibility,

  /// The instance owner or a delegate switches assistants on for the
  /// whole installation.
  installation,

  /// The person connects an assistant and approves this workspace.
  connect,
}

enum AssistantSetupState {
  done,

  /// The actor named on the step can take it now.
  todo,

  /// Someone else has to act first; the step names who.
  waiting,

  /// An earlier step of this list has to be done first.
  blocked,

  /// The server could not be asked, or answered something unreadable.
  unavailable,
}

/// Who takes a step — a role, never a person's private address.
enum AssistantSetupActor {
  you,
  configurer,
  integrations,
  databaseAdministrator,
  instanceOperator,
}

class AssistantSetupItem {
  const AssistantSetupItem(
    this.step,
    this.state,
    this.actor, {
    this.canAct = false,
  });

  final AssistantSetupStep step;
  final AssistantSetupState state;
  final AssistantSetupActor actor;

  /// Whether the person looking holds what the step's action needs. The
  /// server checks again on every call; this only decides what to offer.
  final bool canAct;
}

/// #1827 — "Use the recommended set": a member's own records (read and
/// write) plus the two workspace reads booking needs, within what the
/// server implements. No financial, membership or validation operation.
Set<String> recommendedMcpOperations(Iterable<String> available) => {
  for (final op in available)
    if (mcpOperations[op] case final spec?)
      if (spec.dispatch &&
          mcpOperationGroup(op) == McpOperationGroup.own &&
          (spec.scope == McpScope.own ||
              (spec.authority == McpAuthority.member &&
                  spec.mutation == McpMutation.read)))
        op,
};

class AssistantSetup {
  const AssistantSetup(this.items);

  final List<AssistantSetupItem> items;

  AssistantSetupItem item(AssistantSetupStep step) =>
      items.firstWhere((i) => i.step == step);

  /// The first step not done, or null when everything is.
  AssistantSetupItem? get next =>
      items.where((i) => i.state != AssistantSetupState.done).firstOrNull;

  factory AssistantSetup.derive({
    required String workspaceId,
    required IdentityBindingStatus? identity,
    required DatabaseCapabilities? capabilities,
    required McpPolicy? policy,
    required List<McpConnectionInfo>? connections,
    required bool featureOn,
    required bool canConfigure,
    required bool canManageIntegrations,
  }) {
    const done = AssistantSetupState.done;
    const todo = AssistantSetupState.todo;
    const waiting = AssistantSetupState.waiting;
    const blocked = AssistantSetupState.blocked;
    const unavailable = AssistantSetupState.unavailable;

    final linked = switch (mcpIdentityState(identity)) {
      McpIdentityState.verified => done,
      McpIdentityState.unlinked => todo,
      McpIdentityState.unavailable => unavailable,
    };

    final workspace = featureOn ? done : (canConfigure ? todo : waiting);

    final forWs = policy != null && policy.workspaceId == workspaceId
        ? policy
        : null;
    final offered = forWs == null
        ? unavailable
        : forWs.featureEnabled && forWs.enabled && forWs.operations.isNotEmpty
        ? done
        : !featureOn
        ? blocked
        : canManageIntegrations
        ? todo
        : waiting;

    final eligibility = switch (mcpEligibilityState(capabilities)) {
      McpEligibilityState.approved => done,
      McpEligibilityState.pending => waiting,
      McpEligibilityState.notRequested ||
      McpEligibilityState.revoked => linked == done ? todo : blocked,
      McpEligibilityState.unavailable => unavailable,
    };

    final installation =
        capabilities == null ||
            capabilities.eligibility == McpEligibility.unavailable
        ? unavailable
        : capabilities.runtimeEnabled
        ? done
        : waiting;

    final connected = connections?.any(
      (c) => c.workspaces.any((w) => w.id == workspaceId),
    );
    final connect = connected == null
        ? unavailable
        : connected
        ? done
        : [offered, eligibility, installation].every((x) => x == done)
        ? todo
        : blocked;

    return AssistantSetup([
      AssistantSetupItem(
        AssistantSetupStep.identity,
        linked,
        AssistantSetupActor.you,
        canAct: linked == todo,
      ),
      AssistantSetupItem(
        AssistantSetupStep.workspace,
        workspace,
        AssistantSetupActor.integrations,
        canAct: workspace == todo,
      ),
      AssistantSetupItem(
        AssistantSetupStep.policy,
        offered,
        AssistantSetupActor.integrations,
        canAct: canManageIntegrations && forWs != null && featureOn,
      ),
      AssistantSetupItem(
        AssistantSetupStep.eligibility,
        eligibility,
        eligibility == waiting
            ? AssistantSetupActor.databaseAdministrator
            : AssistantSetupActor.you,
        canAct: eligibility == todo,
      ),
      AssistantSetupItem(
        AssistantSetupStep.installation,
        installation,
        AssistantSetupActor.instanceOperator,
      ),
      AssistantSetupItem(
        AssistantSetupStep.connect,
        connect,
        AssistantSetupActor.you,
        canAct: connect == todo,
      ),
    ]);
  }
}
