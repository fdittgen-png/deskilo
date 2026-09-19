// SPDX-License-Identifier: 0BSD
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

  /// Defines or redefines a role; returns its id.
  Future<String> setRole(String workspaceId, WorkspaceRole role);

  /// Gives [roleId] to [memberId], or takes it back.
  Future<void> assignRole({
    required String memberId,
    required String roleId,
    required bool assign,
  });
}
