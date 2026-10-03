// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1528 — defining a role, and giving it to somebody.
//
// Two writes, both through 0247's definers. Defining is the owner's;
// assigning needs `manageRoles` and never applies to the caller, and the
// server refuses either way — the client asks the same questions first
// so an owner meets a disabled control rather than an error.
import 'workspace_role.dart';

abstract class WorkspaceRolesRepository {
  /// The roles this workspace defined.
  Future<List<WorkspaceRole>> fetchRoles(String workspaceId);

  /// Member ids holding [roleId].
  Future<List<String>> fetchRoleMembers(String roleId);

  /// #2085 — every assignment in [workspaceId]: member id → role ids.
  Future<Map<String, Set<String>>> fetchAssignments(String workspaceId);

  /// Defines or redefines a role; returns its id.
  Future<String> setRole(String workspaceId, WorkspaceRole role);

  /// #2085 — renames the built-in Administrator (owner only).
  Future<void> renameAdministrator(String workspaceId, Map<String, String> names);

  /// #2085 — the roles an unused member invitation carries; they are
  /// given when the person becomes an active member.
  Future<void> setInvitationRoles(
    String workspaceId,
    String code,
    List<String> roleKeys,
  );

  /// Gives [roleId] to [memberId], or takes it back.
  Future<void> assignRole({
    required String memberId,
    required String roleId,
    required bool assign,
  });
}
