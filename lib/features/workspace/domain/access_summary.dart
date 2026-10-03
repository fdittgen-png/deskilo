// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2085 — "What you can do here": every permission a member holds,
// grouped by where it comes from.
//
// It is built from the same pieces as `effectivePermissions`, so the
// screen cannot promise anything the gates do not grant:
//
//   * the member's base, which is exactly ONE of owner, co-owner,
//     Administrator or "Every member", as `permissionRoleOf` decides.
//     "Every member" applies only to members without another base, which
//     is how `has_permission_raw` has always read the member row;
//   * then each of the workspace's own roles the member holds, while
//     `customRoles` is effective and the role is in use.
import 'member.dart';
import 'workspace.dart';
import 'workspace_feature.dart';
import 'workspace_permission.dart';
import 'workspace_role.dart';

/// Where a group of permissions comes from.
enum AccessSourceKind { owner, coOwner, administrator, everyMember, role }

/// One group of "What you can do here".
class AccessSource {
  const AccessSource(this.kind, this.permissions, {this.role});

  final AccessSourceKind kind;

  /// Set for [AccessSourceKind.role] only.
  final WorkspaceRole? role;

  final Set<WorkspacePermission> permissions;
}

/// [member]'s permissions in [workspace], one group per source.
///
/// [heldRoleIds] are the ids of the workspace's own roles the member
/// holds. A member who is not active holds nothing, as on the server.
List<AccessSource> accessSources({
  required Member? member,
  required Workspace? workspace,
  List<WorkspaceRole> roles = const [],
  Set<String> heldRoleIds = const {},
}) {
  if (member == null || member.status != MemberStatus.active) return const [];
  final base = permissionRoleOf(member);
  final sources = <AccessSource>[
    AccessSource(
      switch (base) {
        PermissionRole.owner => AccessSourceKind.owner,
        PermissionRole.coOwner => AccessSourceKind.coOwner,
        PermissionRole.admin => AccessSourceKind.administrator,
        PermissionRole.member => AccessSourceKind.everyMember,
      },
      permissionsForRole(base, workspace),
    ),
  ];
  final customOn = workspace != null &&
      effectiveFeatures(resolveEnabledFeatures(workspace.featureFlags))
          .contains(WorkspaceFeature.customRoles);
  if (!customOn) return sources;
  for (final role in orderedRoles(roles)) {
    // The Administrator's permissions are the base above, never a role row.
    if (role.builtin || !role.active || !heldRoleIds.contains(role.id)) {
      continue;
    }
    sources.add(
      AccessSource(AccessSourceKind.role, role.permissions, role: role),
    );
  }
  return sources;
}

/// Everything [sources] grant together, the same set the gates read.
Set<WorkspacePermission> grantedBy(List<AccessSource> sources) => {
      for (final source in sources) ...source.permissions,
    };
