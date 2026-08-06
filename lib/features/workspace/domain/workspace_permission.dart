// SPDX-License-Identifier: 0BSD
import 'member.dart';
import 'workspace.dart';
import 'workspace_feature.dart';

/// #513 — the central permission catalog. One list, mirrored by the
/// server's `has_permission`/`set_role_permissions` catalog: adding a
/// permission means adding it HERE, in the SQL catalog, and nowhere
/// else — every gate then consults the same matrix.
enum WorkspacePermission {
  /// Edit the role→permission matrix itself.
  manageRoles,

  /// Invite, pause, exit members; change their subscriptions.
  manageMembers,

  /// Configure the validation policies (§6).
  manageValidation,

  /// Edit workspace settings (identity, booking rules, features…).
  workspaceSettings,

  /// Issue invoices, match payments, send reminders — the invoicing
  /// delegation that used to be the adminInvoicing feature flag alone.
  issueInvoices,

  /// Read the workspace-wide finances (ledger, invoicing hub).
  viewFinances,

  /// Manage the document library links.
  manageDocuments,

  /// Manage services, packages, fee bands.
  manageServices,

  /// Approve expense submissions.
  approveExpenses;

  /// The wire name — identical to the Dart name, pinned by test.
  String get wireName => name;
}

/// The role rows of the matrix. OWNER is not part of the stored map —
/// owners always hold everything.
enum PermissionRole { owner, coOwner, admin, member }

extension PermissionRoleWire on PermissionRole {
  String get wireName => switch (this) {
        PermissionRole.owner => 'owner',
        PermissionRole.coOwner => 'co_owner',
        PermissionRole.admin => 'admin',
        PermissionRole.member => 'member',
      };
}

/// The defaults an UNCONFIGURED matrix row grants — exactly today's
/// behavior, so a workspace that never opens the matrix changes
/// nothing.
Set<WorkspacePermission> defaultPermissionsFor(PermissionRole role) =>
    switch (role) {
      PermissionRole.owner => WorkspacePermission.values.toSet(),
      // "Co-owner can have less" — the DEFAULT is everything; the
      // owner removes what they want.
      PermissionRole.coOwner => WorkspacePermission.values.toSet(),
      PermissionRole.admin => {
          WorkspacePermission.manageMembers,
          WorkspacePermission.manageDocuments,
          WorkspacePermission.manageServices,
          WorkspacePermission.approveExpenses,
          WorkspacePermission.viewFinances,
        },
      PermissionRole.member => <WorkspacePermission>{},
    };

/// The role row [member] reads in the matrix.
PermissionRole permissionRoleOf(Member member) {
  if (member.isOwner) return PermissionRole.owner;
  if (member.coOwner == CoOwnerStatus.active) return PermissionRole.coOwner;
  if (member.isAdmin) return PermissionRole.admin;
  return PermissionRole.member;
}

/// The permissions [role] holds under [workspace]'s stored matrix —
/// stored row wins, defaults otherwise. Mirrors `has_permission`.
Set<WorkspacePermission> permissionsForRole(
  PermissionRole role,
  Workspace? workspace,
) {
  if (role == PermissionRole.owner) return WorkspacePermission.values.toSet();
  final stored = workspace?.rolePermissions[role.wireName];
  var granted = stored is List
      ? {
          for (final name in stored)
            for (final p in WorkspacePermission.values)
              if (p.wireName == name) p,
        }
      : defaultPermissionsFor(role);
  // Legacy compatibility: the adminInvoicing feature flag keeps
  // granting invoicing to admins, exactly like the server helper.
  if (role == PermissionRole.admin &&
      workspace != null &&
      workspace.featureFlags[WorkspaceFeature.adminInvoicing.name] == true) {
    granted = {...granted, WorkspacePermission.issueInvoices};
  }
  return granted;
}

/// The effective permissions of [member] — the single client-side
/// entry point (myPermissionsProvider wraps it).
Set<WorkspacePermission> effectivePermissions(
  Member? member,
  Workspace? workspace,
) {
  if (member == null || member.status != MemberStatus.active) {
    return const {};
  }
  return permissionsForRole(permissionRoleOf(member), workspace);
}
