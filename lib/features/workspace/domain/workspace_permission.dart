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
  approveExpenses,

  /// #749 — read a member's commercial agreement (their deal).
  viewNegotiations,

  /// #749 — propose or change a member's commercial agreement.
  manageNegotiations,

  /// #881 — request a change of a member's payment conditions (the
  /// change itself goes through validation).
  paymentTermsEdit,

  // #982 — what "is admin" and "is owner" guarded, as permissions.

  /// Sites, level assignment, other members' home site.
  manageSites,

  /// Fee bands, VAT rates, number sequences, billing and reminder rules.
  manageBilling,

  /// Book for others, cancel, check in and out, block seats, everyone's
  /// calendar.
  manageReservations,

  /// Kiosk assignment, badges.
  operateKiosk,

  /// Accounting exports, the archive bundle, Excel, the configuration
  /// export.
  exportData,

  /// Templates, texts, layouts of the documents.
  designDocuments,

  /// E-mails, managed identities, postal data of members.
  viewPersonalData,

  /// Payment providers, e-invoice credentials, the WhatsApp channel.
  manageIntegrations,

  /// Features, environment, workspace code, imports, reset.
  manageConfiguration;

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
          WorkspacePermission.viewNegotiations,
          WorkspacePermission.manageNegotiations,
          WorkspacePermission.paymentTermsEdit,
          // #982 — what admins could always do, now as permissions.
          WorkspacePermission.manageSites,
          WorkspacePermission.manageReservations,
          WorkspacePermission.operateKiosk,
          WorkspacePermission.exportData,
          WorkspacePermission.viewPersonalData,
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
