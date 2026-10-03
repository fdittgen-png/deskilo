// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — what stands between one member and a first assistant call in
// the selected workspace, as one ordered list. Every row names who acts
// (you, a workspace administrator, a database administrator, the
// operator) and the ONE action that moves it, so a blocked state always
// says what happens next. The facts are the server's answers, read the
// same way as McpAccessStatus; nothing missing is promoted to done.
import '../../auth/domain/database_capabilities.dart';
import '../domain/mcp_access_status.dart';

enum ConnectStep { google, identity, access, workspace, server, connect }

enum ConnectState {
  done,

  /// The person looking takes it now.
  todo,

  /// Someone else acts; the row names who.
  waiting,

  /// A row above has to be done first.
  blocked,

  /// The server could not be asked, or answered something unreadable.
  unavailable,
}

enum ConnectActor { you, workspaceAdmin, databaseAdministrator, operator }

/// The one thing the row offers. `none` when nothing can be done here.
enum ConnectAction {
  none,
  linkGoogle,
  signInWithGoogle,
  confirmIdentity,
  requestAccess,
  openSetup,
  openInstallation,
  askOperator,
  addConnector,
}

class ConnectItem {
  const ConnectItem(
    this.step,
    this.state,
    this.actor, {
    this.action = ConnectAction.none,
    this.expiresInDays,
    this.roleDenied = false,
  });

  final ConnectStep step;
  final ConnectState state;
  final ConnectActor actor;
  final ConnectAction action;

  /// Days until an approved access lapses; null when it is not approved.
  final int? expiresInDays;

  /// The workspace offers assistants, but nothing to this person's role.
  final bool roleDenied;
}

/// An approval this close to its end is announced on its row.
const accessExpiryWarningDays = 14;

class ConnectChecklist {
  const ConnectChecklist(this.items);

  final List<ConnectItem> items;

  ConnectItem item(ConnectStep step) => items.firstWhere((i) => i.step == step);

  /// The first row not done, or null when everything is.
  ConnectItem? get next =>
      items.where((i) => i.state != ConnectState.done).firstOrNull;

  /// Whether the approval is close enough to its end to say so.
  bool get accessExpiresSoon {
    final days = item(ConnectStep.access).expiresInDays;
    return days != null && days <= accessExpiryWarningDays;
  }

  factory ConnectChecklist.derive({
    required McpAccessStatus status,
    required DatabaseCapabilities? capabilities,
    required DateTime now,
    bool isOperator = false,
    bool canManageIntegrations = false,
    bool workspaceOn = true,
  }) {
    const done = ConnectState.done;
    const todo = ConnectState.todo;
    const waiting = ConnectState.waiting;
    const blocked = ConnectState.blocked;
    const unavailable = ConnectState.unavailable;
    const you = ConnectActor.you;

    final google = switch (status.google) {
      McpGoogleState.ready => const ConnectItem(ConnectStep.google, done, you),
      McpGoogleState.linkGoogle => const ConnectItem(
        ConnectStep.google,
        todo,
        you,
        action: ConnectAction.linkGoogle,
      ),
      McpGoogleState.signInWithGoogle => const ConnectItem(
        ConnectStep.google,
        todo,
        you,
        action: ConnectAction.signInWithGoogle,
      ),
      McpGoogleState.unavailable => const ConnectItem(
        ConnectStep.google,
        unavailable,
        you,
      ),
    };

    final identity = google.state != done
        ? const ConnectItem(ConnectStep.identity, blocked, you)
        : switch (status.identity) {
            McpIdentityState.verified => const ConnectItem(
              ConnectStep.identity,
              done,
              you,
            ),
            McpIdentityState.unlinked => const ConnectItem(
              ConnectStep.identity,
              todo,
              you,
              action: ConnectAction.confirmIdentity,
            ),
            McpIdentityState.unavailable => const ConnectItem(
              ConnectStep.identity,
              unavailable,
              you,
            ),
          };

    final until = capabilities?.eligibleUntil;
    final access = identity.state != done
        ? const ConnectItem(ConnectStep.access, blocked, you)
        : switch (status.eligibility) {
            McpEligibilityState.approved => ConnectItem(
              ConnectStep.access,
              done,
              you,
              expiresInDays: until?.difference(now).inDays.clamp(0, 1 << 16),
            ),
            McpEligibilityState.notRequested ||
            McpEligibilityState.revoked => const ConnectItem(
              ConnectStep.access,
              todo,
              you,
              action: ConnectAction.requestAccess,
            ),
            // Nobody decides their own request; the operator can at least
            // name an administrator from the installation console.
            McpEligibilityState.pending => ConnectItem(
              ConnectStep.access,
              waiting,
              ConnectActor.databaseAdministrator,
              action: isOperator
                  ? ConnectAction.openInstallation
                  : ConnectAction.none,
            ),
            McpEligibilityState.unavailable => const ConnectItem(
              ConnectStep.access,
              unavailable,
              you,
            ),
          };

    final admin = canManageIntegrations ? you : ConnectActor.workspaceAdmin;
    final setup = canManageIntegrations
        ? ConnectAction.openSetup
        : ConnectAction.none;
    final workspace = !workspaceOn
        ? ConnectItem(
            ConnectStep.workspace,
            canManageIntegrations ? todo : waiting,
            admin,
            action: setup,
          )
        : switch (status.exposure) {
            McpExposureState.disabled => ConnectItem(
              ConnectStep.workspace,
              canManageIntegrations ? todo : waiting,
              admin,
              action: setup,
            ),
            McpExposureState.exposed => switch (status.role) {
              McpRoleState.allowed => const ConnectItem(
                ConnectStep.workspace,
                done,
                you,
              ),
              McpRoleState.denied => ConnectItem(
                ConnectStep.workspace,
                canManageIntegrations ? todo : waiting,
                admin,
                action: setup,
                roleDenied: true,
              ),
              // What a role may do is only answered once access is approved.
              McpRoleState.unavailable => ConnectItem(
                ConnectStep.workspace,
                access.state == done ? unavailable : blocked,
                you,
              ),
            },
            // A member learns the offer only once approved (0276); approved and
            // still not offered here means nothing is offered to this role.
            McpExposureState.unavailable
                when status.role == McpRoleState.denied =>
              ConnectItem(
                ConnectStep.workspace,
                canManageIntegrations ? todo : waiting,
                admin,
                action: setup,
                roleDenied: true,
              ),
            McpExposureState.unavailable => ConnectItem(
              ConnectStep.workspace,
              access.state == done ? unavailable : blocked,
              you,
            ),
          };

    final server =
        capabilities == null ||
            capabilities.eligibility == McpEligibility.unavailable
        ? const ConnectItem(
            ConnectStep.server,
            unavailable,
            ConnectActor.operator,
          )
        : capabilities.runtimeEnabled
        ? const ConnectItem(ConnectStep.server, done, ConnectActor.operator)
        : isOperator
        ? const ConnectItem(
            ConnectStep.server,
            todo,
            you,
            action: ConnectAction.openInstallation,
          )
        : const ConnectItem(
            ConnectStep.server,
            waiting,
            ConnectActor.operator,
            action: ConnectAction.askOperator,
          );

    final before = [google, identity, access, workspace, server];
    final connect = switch (status.consent) {
      McpConsentState.current => const ConnectItem(
        ConnectStep.connect,
        done,
        you,
      ),
      _ when before.any((i) => i.state != done) => const ConnectItem(
        ConnectStep.connect,
        blocked,
        you,
      ),
      McpConsentState.missing => const ConnectItem(
        ConnectStep.connect,
        todo,
        you,
        action: ConnectAction.addConnector,
      ),
      McpConsentState.unavailable => const ConnectItem(
        ConnectStep.connect,
        unavailable,
        you,
      ),
    };

    return ConnectChecklist([...before, connect]);
  }
}

/// #2145 — where one workspace of this installation stands for the
/// person: every workspace decides for itself, the operator switched the
/// installation on once, and the person picks among the ready ones when
/// the assistant asks.
enum WorkspaceAssistantState {
  /// An assistant already holds the person's consent here.
  connected,

  /// Offered to this person: choose it when the assistant asks.
  ready,

  /// Assistants are on here, but nothing is offered to this person.
  notOffered,

  /// The workspace has not turned assistants on.
  off,

  /// Answered once the person's access is approved, or not answered.
  unknown,
}

/// What a workspace row offers when it is not ready.
enum WorkspaceRowAction {
  none,

  /// The selected workspace, and the person manages its integrations.
  openSetup,

  /// Another workspace: switching to it is where its setup is reached.
  switchTo,
}

class WorkspaceAssistantRow {
  const WorkspaceAssistantRow({
    required this.id,
    required this.name,
    required this.state,
    this.current = false,
    this.action = WorkspaceRowAction.none,
  });

  final String id;
  final String name;
  final WorkspaceAssistantState state;

  /// The selected workspace: the one the setup page acts on.
  final bool current;
  final WorkspaceRowAction action;
}

/// One row per workspace the person belongs to, in their order. [mcpOn]
/// is each workspace's own flag; [offered] is what consent would list
/// (null while the person's access is not approved, or not answered);
/// [connected] the workspace ids an assistant already holds.
List<WorkspaceAssistantRow> deriveWorkspaceRows({
  required List<({String id, String name, bool mcpOn})> workspaces,
  required Map<String, int>? offered,
  required Set<String>? connected,
  String? currentId,
  bool canManageCurrent = false,
}) => [
  for (final w in workspaces)
    _row(w, offered, connected, currentId, canManageCurrent),
];

WorkspaceAssistantRow _row(
  ({String id, String name, bool mcpOn}) w,
  Map<String, int>? offered,
  Set<String>? connected,
  String? currentId,
  bool canManageCurrent,
) {
  final state = connected?.contains(w.id) ?? false
      ? WorkspaceAssistantState.connected
      : !w.mcpOn
      ? WorkspaceAssistantState.off
      : offered == null
      ? WorkspaceAssistantState.unknown
      : (offered[w.id] ?? 0) > 0
      ? WorkspaceAssistantState.ready
      : WorkspaceAssistantState.notOffered;
  final current = w.id == currentId;
  final fixable =
      state == WorkspaceAssistantState.off ||
      state == WorkspaceAssistantState.notOffered;
  return WorkspaceAssistantRow(
    id: w.id,
    name: w.name,
    state: state,
    current: current,
    action: !fixable
        ? WorkspaceRowAction.none
        : !current
        ? WorkspaceRowAction.switchTo
        : canManageCurrent
        ? WorkspaceRowAction.openSetup
        : WorkspaceRowAction.none,
  );
}
