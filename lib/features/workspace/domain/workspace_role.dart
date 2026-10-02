// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1528 — a role a workspace defined itself, as the app reads it.
//
// ADR 0029: additive. It never removes a permission and never replaces a
// member's base role, so what the client shows is what the server adds.
// The permissions come from `role_permission_catalog()`, which is why
// they are [WorkspacePermission] values here rather than strings: a role
// cannot hold something the product does not have, and the type says so.
import 'workspace_permission.dart';

class WorkspaceRole {
  const WorkspaceRole({
    required this.id,
    required this.key,
    required this.names,
    this.permissions = const {},
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;

  /// Stable, written once: the assignments point at it.
  final String key;

  /// Locale → name, so a member reads the role in their own language.
  final Map<String, String> names;

  final Set<WorkspacePermission> permissions;
  final int sortOrder;
  final bool active;

  /// The four the product decided, which 0247 refuses to redefine.
  static const builtInKeys = {'owner', 'co_owner', 'admin', 'member'};

  String nameIn(String locale, {String fallbackLocale = 'en'}) =>
      names[locale] ?? names[fallbackLocale] ?? key;
}

/// The roles a space defined, in the order a list shows them.
List<WorkspaceRole> orderedRoles(Iterable<WorkspaceRole> roles) =>
    [...roles]..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
    });

/// Why [role] cannot be saved, or null. The same four refusals 0247
/// raises, so an owner meets them as a disabled button rather than as an
/// error from the server.
RoleProblem? roleProblem(WorkspaceRole role, String workspaceLocale) {
  if (WorkspaceRole.builtInKeys.contains(role.key)) return RoleProblem.builtIn;
  if (!RegExp(r'^[a-z][a-z0-9_]{1,30}$').hasMatch(role.key)) {
    return RoleProblem.key;
  }
  final own = role.names[workspaceLocale];
  if (own == null || own.trim().isEmpty) return RoleProblem.name;
  return null;
}

enum RoleProblem {
  /// One of the four the product decided.
  builtIn,

  /// Not lower-case letters, digits and underscores.
  key,

  /// No name in the language the workspace reads.
  name,
}
