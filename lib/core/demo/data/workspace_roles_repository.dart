// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1528 — the roles a workspace defined, in memory.
//
// It refuses what 0247 refuses, because a fake that accepts a built-in
// key or a self-assignment lets a screen ship a Save the server rejects,
// with every screen test green.
import '../../../features/workspace/domain/workspace_role.dart';
import '../../../features/workspace/domain/workspace_roles_repository.dart';

class FakeWorkspaceRoles implements WorkspaceRolesRepository {
  final roles = <WorkspaceRole>[];

  /// role id → member ids.
  final assignments = <String, List<String>>{};

  /// The member the caller is, so a self-assignment can be refused the
  /// way `assign_workspace_role` refuses it.
  String callerMemberId = 'member-1';

  @override
  Future<List<WorkspaceRole>> fetchRoles(String workspaceId) async =>
      List.of(roles);

  @override
  Future<List<String>> fetchRoleMembers(String roleId) async =>
      List.of(assignments[roleId] ?? const []);

  @override
  Future<String> setRole(String workspaceId, WorkspaceRole role) async {
    if (WorkspaceRole.builtInKeys.contains(role.key)) {
      throw StateError('the built-in roles are not redefined here');
    }
    final at = roles.indexWhere((r) => r.key == role.key);
    final id = at >= 0
        ? roles[at].id
        : (role.id.isEmpty ? 'role-${roles.length + 1}' : role.id);
    final stored = WorkspaceRole(
      id: id,
      key: role.key,
      names: role.names,
      permissions: role.permissions,
      sortOrder: role.sortOrder,
      active: role.active,
    );
    if (at >= 0) {
      roles[at] = stored;
    } else {
      roles.add(stored);
    }
    return id;
  }

  @override
  Future<void> assignRole({
    required String memberId,
    required String roleId,
    required bool assign,
  }) async {
    if (memberId == callerMemberId) {
      throw StateError('a role is never assigned to yourself');
    }
    final held = assignments[roleId] ??= [];
    if (assign) {
      if (!held.contains(memberId)) held.add(memberId);
    } else {
      held.remove(memberId);
    }
  }
}
