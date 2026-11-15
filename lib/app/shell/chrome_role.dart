// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4019 — the chrome names the reader's role where the role decides what the
// page can do: "as owner", "as administrator", "as <role>", "as member".
// A route declares it (`namesRole` in route_classes.dart); nothing here
// lists pages. The role is the reader's membership in the current business,
// from the same providers the shell reads for permissions.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/context_l10n.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/organisation.dart';
import '../../features/workspace/domain/role_assignment.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../features/workspace/providers/workspace_roles_providers.dart';
import '../../l10n/app_localizations.dart';
import '../route_classes.dart';

/// The reader's role in the current business: the built-in kind and, for a
/// member holding one of the business's own roles, that role's names by
/// language.
@visibleForTesting
class ChromeRole {
  const ChromeRole(
    this.kind, {
    this.names = const {},
    this.adminNames = const {},
  });
  final HouseRole kind;

  /// A named role held by a member who is neither owner nor administrator.
  final Map<String, String> names;

  /// What the business calls its Administrator (the owner may rename it).
  final Map<String, String> adminNames;
}

/// The reader's role here, or null while the membership is unknown.
@visibleForTesting
final chromeRoleProvider = Provider<ChromeRole?>((ref) {
  final me = ref.watch(myMemberProvider).value;
  if (me == null) return null;
  final roles = ref.watch(workspaceRolesProvider).value ?? const []; // empty-ok: no roles known, no named role; the built-in words stand
  final assignments = ref.watch(workspaceRoleAssignmentsProvider).value ?? const {}; // empty-ok: no assignments known, no named role
  if (me.isOwner) return const ChromeRole(HouseRole.owner);
  if (me.coOwner == CoOwnerStatus.active) {
    return const ChromeRole(HouseRole.coOwner);
  }
  if (me.isAdmin) {
    return ChromeRole(
      HouseRole.admin,
      adminNames: administratorRole(roles)?.names ?? const {},
    );
  }
  final held = rolesHeldBy(me.id, roles, assignments);
  if (held.isNotEmpty) {
    return ChromeRole(HouseRole.member, names: held.first.names);
  }
  return const ChromeRole(HouseRole.member);
});

String _ownName(Map<String, String> names, String locale, String fallback) {
  final own = names[locale] ?? names['en'];
  return own == null || own.trim().isEmpty ? fallback : own;
}

/// "as owner" in the reader's language: the built-in words of the
/// organisation page, or the role's own name.
@visibleForTesting
String chromeRoleWords(AppLocalizations l10n, ChromeRole role, String locale) {
  final word = switch (role.kind) {
    HouseRole.owner => l10n.organisationRoleOwner,
    HouseRole.coOwner => l10n.organisationRoleCoOwner,
    HouseRole.admin => _ownName(
      role.adminNames,
      locale,
      l10n.organisationRoleAdmin,
    ),
    HouseRole.member =>
      role.names.isEmpty
          ? l10n.organisationRoleMember
          : _ownName(role.names, locale, l10n.organisationRoleMember),
  };
  return l10n.chromeRoleAs(word);
}

/// The words the chrome shows for [path], or null where the page does not
/// declare that the role decides it, or the role is not known yet.
String? chromeRoleFor(BuildContext context, WidgetRef ref, String? path) {
  if (path == null || !(matchRoute(path)?.namesRole ?? false)) return null;
  final role = ref.watch(chromeRoleProvider);
  if (role == null) return null;
  return chromeRoleWords(
    context.l10n,
    role,
    Localizations.localeOf(context).languageCode,
  );
}
