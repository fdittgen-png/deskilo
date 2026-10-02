// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_workspace_roles.dart';
import '../domain/role_assignment.dart';
import '../domain/workspace_feature.dart';
import '../domain/workspace_permission.dart';
import '../domain/workspace_role.dart';
import '../domain/workspace_roles_repository.dart';
import 'workspace_providers.dart';

part 'workspace_roles_providers.g.dart';

/// #1528 — the roles a workspace defined itself.
@Riverpod(keepAlive: true)
WorkspaceRolesRepository workspaceRolesRepository(Ref ref) =>
    SupabaseWorkspaceRoles(Supabase.instance.client);

/// The active workspace's own roles, or none while the feature is off.
///
/// The flag is read here rather than on each surface, so a space that
/// never turned it on makes no request at all.
@riverpod
Future<List<WorkspaceRole>> workspaceRoles(Ref ref) async {
  if (!ref
      .watch(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.customRoles)) {
    return const [];
  }
  final pending = ref.watch(currentWorkspaceProvider.future);
  final repository = ref.watch(workspaceRolesRepositoryProvider);
  final workspace = await pending;
  if (workspace == null) return const [];
  return orderedRoles(await repository.fetchRoles(workspace.id));
}

/// Who holds one role.
@riverpod
Future<List<String>> roleMembers(Ref ref, String roleId) async {
  final repository = ref.watch(workspaceRolesRepositoryProvider);
  return repository.fetchRoleMembers(roleId);
}

/// #2085 — who holds which of the workspace's own roles: member id → the
/// ids of the roles they hold. Empty while the feature is off, like the
/// roles themselves.
@riverpod
Future<Map<String, Set<String>>> workspaceRoleAssignments(Ref ref) async {
  if (!ref
      .watch(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.customRoles)) {
    return const {};
  }
  final pending = ref.watch(currentWorkspaceProvider.future);
  final repository = ref.watch(workspaceRolesRepositoryProvider);
  final workspace = await pending;
  if (workspace == null) return const {};
  return repository.fetchAssignments(workspace.id);
}

/// #2085 — what the roles I hold add to my permissions.
///
/// `has_permission` has counted them since 0247; the app did not, so a
/// treasurer was granted the finances by the server and never shown the
/// way there. `effectivePermissions` still drops them while `customRoles`
/// is off, exactly as the server does.
@riverpod
Set<WorkspacePermission> myRolePermissions(Ref ref) {
  final me = ref.watch(myMemberProvider).value;
  if (me == null) return const {};
  final roles = ref.watch(workspaceRolesProvider).value ?? const <WorkspaceRole>[];
  final assignments = ref.watch(workspaceRoleAssignmentsProvider).value ??
      const <String, Set<String>>{};
  return {
    for (final role in rolesHeldBy(me.id, roles, assignments))
      if (role.active) ...role.permissions,
  };
}
