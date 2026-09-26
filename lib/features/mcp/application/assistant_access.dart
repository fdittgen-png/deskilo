// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1628 — what a person does with their own assistant access on this
// database: ask for or give up eligibility, remove one workspace from a
// connection, disconnect an assistant entirely. Removing one workspace
// never revokes the provider grant (that would disconnect the others);
// only a full disconnect does.
import '../../auth/domain/identity_binding.dart';
import '../domain/mcp_connection.dart';

class AssistantAccess {
  const AssistantAccess(this._connections, this._identity);
  final McpConnectionRepository _connections;
  final IdentityBindingRepository _identity;

  Future<DatabaseCapabilities> requestEligibility() =>
      _identity.requestMcpEligibility();
  Future<DatabaseCapabilities> withdrawEligibility() =>
      _identity.withdrawMcpEligibility();
  Future<void> removeWorkspace(String clientId, String workspaceId) =>
      _connections.revokeScope(clientId, workspaceId);
  Future<void> disconnect(String clientId) => _connections.disconnect(clientId);
}
