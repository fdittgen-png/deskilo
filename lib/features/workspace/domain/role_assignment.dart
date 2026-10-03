// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2085 — who may give which role to whom.
//
// Everyone in a workspace is a member. Beyond that, what a person can do
// comes only from roles. These rules decide whether a role can be given
// to (or taken back from) a member, and why not. The server asks the same
// questions (0035 for the Administrator, 0247 for a workspace's own
// roles); the client asks them first, so a person sees a role they cannot
// give as disabled, with the reason, instead of meeting an error.
//
//   * Nobody gives a role to themselves.
//   * The Administrator role goes through the validation quorum, and only
//     the owner asks for it (`request_role_change`).
//   * A workspace's own role is given by whoever holds manageRoles. Unless
//     they are the owner, they may only give a role whose permissions they
//     hold themselves, and never one that carries manageRoles (the owner's
//     decision on #2085).
import 'member.dart';
import 'workspace_permission.dart';
import 'workspace_role.dart';

/// Why a role cannot be given to, or taken from, a member.
enum RoleRefusal {
  /// The caller is the member.
  yourself,

  /// The caller may not give roles at all.
  notPermitted,

  /// The role carries manageRoles, which only the owner gives.
  ownerOnly,

  /// The role holds a permission the caller does not hold.
  exceedsYours,

  /// The member cannot hold this role: the owner, a co-owner who already
  /// holds every owner permission, a kiosk, someone not active, or a role
  /// that has been put aside.
  notAssignable,
}

bool _active(Member m) => m.status == MemberStatus.active;

/// Why [caller] cannot ask for the Administrator role to be given to (or
/// taken from) [subject], or null when they can.
RoleRefusal? administratorRefusal({
  required Member caller,
  required Member subject,
}) {
  if (caller.id == subject.id) return RoleRefusal.yourself;
  if (!caller.actsAsOwner) return RoleRefusal.notPermitted;
  if (subject.isOwner ||
      subject.isKiosk ||
      !_active(subject) ||
      subject.coOwner == CoOwnerStatus.active) {
    return RoleRefusal.notAssignable;
  }
  return null;
}

/// Why [caller], holding [callerPermissions], cannot give [role] to
/// [subject] (or, with [granting] false, take it back), or null when they
/// can.
///
/// A role that was put aside cannot be given, but can still be taken
/// back: a holder must not be stuck with a role nobody uses any more.
RoleRefusal? customRoleRefusal({
  required Member caller,
  required Set<WorkspacePermission> callerPermissions,
  required Member subject,
  required WorkspaceRole role,
  bool granting = true,
}) {
  if (caller.id == subject.id) return RoleRefusal.yourself;
  if (!callerPermissions.contains(WorkspacePermission.manageRoles)) {
    return RoleRefusal.notPermitted;
  }
  if (subject.isKiosk || !_active(subject) || (granting && !role.active)) {
    return RoleRefusal.notAssignable;
  }
  if (caller.actsAsOwner) return null;
  if (role.permissions.contains(WorkspacePermission.manageRoles)) {
    return RoleRefusal.ownerOnly;
  }
  if (!callerPermissions.containsAll(role.permissions)) {
    return RoleRefusal.exceedsYours;
  }
  return null;
}

/// Why [caller] cannot send [role] with a new member's invitation, or
/// null: the rules of [customRoleRefusal], without a member yet (the
/// server asks them again on the day the invitation is used).
RoleRefusal? inviteRoleRefusal({
  required Member caller,
  required Set<WorkspacePermission> callerPermissions,
  required WorkspaceRole role,
}) {
  if (role.builtin || !role.active) return RoleRefusal.notAssignable;
  if (!callerPermissions.contains(WorkspacePermission.manageRoles)) {
    return RoleRefusal.notPermitted;
  }
  if (caller.actsAsOwner) return null;
  if (role.permissions.contains(WorkspacePermission.manageRoles)) {
    return RoleRefusal.ownerOnly;
  }
  if (!callerPermissions.containsAll(role.permissions)) {
    return RoleRefusal.exceedsYours;
  }
  return null;
}

/// Whether [member] holds the built-in Administrator role, as opposed to
/// the owner permissions that an owner or an active co-owner hold anyway.
bool holdsAdministrator(Member member) =>
    member.isAdmin &&
    !member.isOwner &&
    member.coOwner != CoOwnerStatus.active;

/// The built-in Administrator among [roles], if the server sent it.
WorkspaceRole? administratorRole(Iterable<WorkspaceRole> roles) {
  for (final role in roles) {
    if (role.builtin) return role;
  }
  return null;
}

/// What the Administrator is called here, in [locale]: the owner may
/// rename it; [fallback] is the product's word.
String administratorName(
  Iterable<WorkspaceRole> roles,
  String locale,
  String fallback,
) {
  final role = administratorRole(roles);
  if (role == null) return fallback;
  final own = role.names[locale] ?? role.names['en'];
  return (own == null || own.trim().isEmpty) ? fallback : own;
}

/// The workspace's own roles [member] holds, in display order.
List<WorkspaceRole> rolesHeldBy(
  String memberId,
  List<WorkspaceRole> roles,
  Map<String, Set<String>> assignments,
) {
  final held = assignments[memberId] ?? const <String>{};
  return [
    for (final role in orderedRoles(roles))
      // The Administrator shows as its own chip: who holds it is
      // `is_admin`, and it is given through the quorum.
      if (held.contains(role.id) && !role.builtin) role,
  ];
}
