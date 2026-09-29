// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1628 — what a person does with their own assistant access on this
// database: ask for or give up eligibility, remove one workspace from a
// connection, disconnect an assistant entirely. Removing one workspace
// never revokes the provider grant (that would disconnect the others);
// only a full disconnect does.
//
// #1625 — both go to the installation the connection was read from, and
// say exactly what they ended: a workspace-scope disconnect ends that
// one workspace's consent for that assistant; a database-level
// disconnect ends every workspace of that assistant on that installation
// and its grant. Neither touches another installation.
//
// #1631 — "what they ended" is the server's answer (McpRevocation), not
// the list the screen was showing when the person tapped.
import '../../auth/domain/identity_binding.dart';
import '../domain/mcp_connection.dart';
import '../domain/mcp_context.dart';
import 'mcp_commands.dart';

enum McpDisconnectScope { workspace, database }

/// What a disconnect ended. [workspaces] are the consents it removed.
class McpDisconnectResult {
  const McpDisconnectResult({
    required this.scope,
    required this.instance,
    required this.clientId,
    required this.workspaces,
  });

  final McpDisconnectScope scope;
  final McpInstanceRef instance;
  final String clientId;
  final Set<String> workspaces;

  /// Whether this result invalidates what is shown for [context].
  bool ends(McpContextRef context) =>
      context.instance == instance && workspaces.contains(context.workspaceId);
}

class AssistantAccess {
  const AssistantAccess(this._commands, this._identity);
  final McpCommands _commands;
  final IdentityBindingRepository _identity;

  Future<DatabaseCapabilities> requestEligibility() =>
      _identity.requestMcpEligibility();
  Future<DatabaseCapabilities> withdrawEligibility() =>
      _identity.withdrawMcpEligibility();

  Future<McpDisconnectResult> removeWorkspace(
    McpConnectionInfo connection,
    String workspaceId,
  ) async {
    final scope = _scope(connection);
    final ended = await _commands.execute(
      McpMutation<Object?>(
        scope: scope,
        operation: 'revoke_mcp_workspace_scope',
        payload: (client: connection.clientId, workspace: workspaceId),
      ),
      (r, m) => r.connections.revokeScope(connection.clientId, workspaceId),
    );
    return _result(McpDisconnectScope.workspace, scope, connection, ended);
  }

  Future<McpDisconnectResult> disconnect(McpConnectionInfo connection) async {
    final scope = _scope(connection);
    final ended = await _commands.execute(
      McpMutation<Object?>(
        scope: scope,
        operation: 'revoke_mcp_connection',
        payload: connection.clientId,
      ),
      (r, m) => r.connections.disconnect(connection.clientId),
    );
    return _result(McpDisconnectScope.database, scope, connection, ended);
  }

  // #1631 — the result is what the server says it ended, on the
  // installation it names. An answer for another installation is refused
  // (typed), never published as this one's; a workspace the screen still
  // listed but the server did not end is not claimed.
  McpDisconnectResult _result(
    McpDisconnectScope kind,
    McpInstanceRef scope,
    McpConnectionInfo connection,
    McpRevocation ended,
  ) {
    requireProvenance(
      ended,
      what: 'installation',
      expected: scope.installationId,
      answered: ended.installationId,
    );
    return McpDisconnectResult(
      scope: kind,
      instance: scope,
      clientId: connection.clientId,
      workspaces: ended.workspaces,
    );
  }

  McpInstanceRef _scope(McpConnectionInfo connection) =>
      connection.scope ?? (throw const McpTargetUnverified(''));
}
