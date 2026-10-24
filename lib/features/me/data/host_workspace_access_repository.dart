// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/backend/context_clients.dart';
import '../domain/workspace_access_repository.dart';

/// #2563 C1 — [WorkspaceAccessRepository] on the verified host of each
/// workspace: the resolver names the installation and its client, never
/// the personal home's.
class HostWorkspaceAccessRepository implements WorkspaceAccessRepository {
  const HostWorkspaceAccessRepository(this._hosts);

  final WorkspaceHostResolver _hosts;

  @override
  Future<void> leaveSpace(String workspaceId) async {
    final host = await _hosts.resolve(workspaceId);
    try {
      await host.client.rpc<void>(
        'leave_workspace',
        params: {'p_workspace_id': workspaceId},
      );
    } finally {
      host.lease?.release();
    }
  }
}
