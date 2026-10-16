// SPDX-License-Identifier: AGPL-3.0-or-later

/// What each role grants.
///
/// A part of [WorkspaceRepository] (#2597): that interface is the sum of
/// these, so no caller changes.
abstract class RolePermissionRepository {
  /// #1089 — grants or revokes ONE permission. The screen must use this
  /// rather than [setRolePermissions]: a whole-list write is computed
  /// from the snapshot the screen was built with, so a concurrent change
  /// to a DIFFERENT permission is erased — and when a validation policy
  /// holds the change, the stale list sits in the event until a
  /// validator confirms it, which makes the window minutes rather than
  /// milliseconds.
  Future<void> setRolePermission(
    String workspaceId,
    String role,
    String permission, {
    required bool enabled,
  });

  /// #513 — replaces one role's granted permission list in the matrix
  /// (server RPC set_role_permissions; caller needs manageRoles).
  /// Whole-list, for the callers that legitimately replace one: the
  /// settings import and the deployment transfer. A SCREEN wants
  /// [setRolePermission].
  Future<void> setRolePermissions(
    String workspaceId,
    String role,
    List<String> permissions,
  );
}
