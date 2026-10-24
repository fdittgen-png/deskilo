// SPDX-License-Identifier: AGPL-3.0-or-later

/// #2563 C1 — the account's calls that act INSIDE a workspace, made on
/// that workspace's own host. [MeRepository] is the personal home's.
abstract interface class WorkspaceAccessRepository {
  /// `leave_workspace` (0001) on the host of [workspaceId]: my membership
  /// becomes `exited`. My data stays; erasing it is the separate, stronger
  /// action in Privacy.
  Future<void> leaveSpace(String workspaceId);
}
