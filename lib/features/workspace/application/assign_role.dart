// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2085 — giving one of the workspace's own roles to a member, or taking
// it back.
//
// The member page, the role editor and the members sheet all say "give"
// or "take back"; this file decides what that writes and what has to be
// read again afterwards, so none of them resolves the repository
// (ADR 0024, the layering ratchet). Whether the caller may do it at all
// is the server's decision (`assign_workspace_role`), asked first on the
// client by `customRoleRefusal`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/workspace_roles_providers.dart';

/// #2085 — the roles an invitation carries, written right after it is
/// created; nothing to write when none was chosen.
Future<void> setInvitationRoles(
  WidgetRef ref, {
  required String workspaceId,
  required String code,
  required Set<String> roleKeys,
}) async {
  if (roleKeys.isEmpty) return;
  await ref
      .read(workspaceRolesRepositoryProvider)
      .setInvitationRoles(workspaceId, code, roleKeys.toList()..sort());
}

/// Gives [roleId] to [memberId] when [assign] is true, takes it back
/// otherwise, then re-reads who holds what.
///
/// Both lists are read again: the assignments feed every member page and
/// the caller's own permissions, the holders feed the role's editor.
Future<void> setMemberRole(
  WidgetRef ref, {
  required String memberId,
  required String roleId,
  required bool assign,
}) async {
  await ref.read(workspaceRolesRepositoryProvider).assignRole(
        memberId: memberId,
        roleId: roleId,
        assign: assign,
      );
  ref
    ..invalidate(workspaceRoleAssignmentsProvider)
    ..invalidate(roleMembersProvider(roleId));
}
