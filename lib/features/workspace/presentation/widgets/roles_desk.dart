// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3628 (desk M9) — the roles at the desk: the roles on the left with how
// many people hold each (the bases owner, co-owner, administrator, every
// member, then the space's own roles); on the right the chosen role's
// permissions, module by module, each with who holds it. The same switches
// as on a phone, the same writes, the same refusals: nothing here changes
// what a role may do. Who holds a permission is read from `accessSources`,
// the pieces the gates are built from, never derived a second way. The
// address names the chosen role (`?role=<id>`).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/task_choice.dart';
import '../../../../core/ui/adaptive/task_surface.dart';
import '../../../../core/ui/kit/kit_metrics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/access_summary.dart';
import '../../domain/member.dart';
import '../../domain/permission_modules.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_permission.dart';
import '../../domain/workspace_role.dart';
import '../../providers/workspace_providers.dart';
import '../../providers/workspace_roles_providers.dart';
import '../screens/roles_screen_labels.dart';

/// One role in the list: a base of the matrix or one of the space's own.
typedef DeskRole = ({
  String id,
  String name,
  PermissionRole? base,
  WorkspaceRole? own,
});

/// The heading of [module].
String permissionModuleName(AppLocalizations l, PermissionModule module) =>
    switch (module) {
      PermissionModule.everyday => l.permModuleEveryday,
      PermissionModule.people => l.permModulePeople,
      PermissionModule.places => l.permModulePlaces,
      PermissionModule.money => l.permModuleMoney,
      PermissionModule.stock => l.permModuleStock,
      PermissionModule.documents => l.permModuleDocuments,
      PermissionModule.configuration => l.permModuleConfiguration,
      PermissionModule.environments => l.permModuleEnvironments,
    };

/// The roles beside the chosen role's permissions.
class RolesDesk extends ConsumerStatefulWidget {
  const RolesDesk({
    super.key,
    required this.roles,
    required this.workspace,
    required this.canEdit,
    required this.myRole,
    required this.onToggle,
    required this.onEditOwn,
    required this.intro,
  });

  final List<DeskRole> roles;
  final Workspace? workspace;

  /// The person may change the bases' permissions (manageRoles).
  final bool canEdit;
  final PermissionRole? myRole;

  /// Turns [permission] on or off for [base] (the matrix write).
  final void Function(
    PermissionRole base,
    WorkspacePermission permission,
    Set<WorkspacePermission> current,
  )
  onToggle;

  /// Opens the editor of one of the space's own roles.
  final void Function(WorkspaceRole role) onEditOwn;

  /// The sentence over the permissions (editable or read only).
  final String intro;

  @override
  ConsumerState<RolesDesk> createState() => _RolesDeskState();
}

class _RolesDeskState extends ConsumerState<RolesDesk> {
  String? _chosen;

  String? _inAddress() => GoRouter.maybeOf(context) == null
      ? null
      : GoRouterState.of(context).uri.queryParameters['role'];

  void _choose(String id) {
    if (GoRouter.maybeOf(context) == null) {
      setState(() => _chosen = id);
      return;
    }
    final uri = GoRouterState.of(context).uri;
    context.replace(
      uri
          .replace(queryParameters: {...uri.queryParameters, 'role': id})
          .toString(),
    );
  }

  /// The active members who are people (not a kiosk).
  List<Member> _people() => [
    for (final m
        in ref.watch(workspaceMembersProvider).value ??
            const <
              Member
            >[]) // empty-ok: nobody is counted before the members are read
      if (m.status == MemberStatus.active && !m.isKiosk) m,
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final people = _people();
    final assignments =
        ref.watch(workspaceRoleAssignmentsProvider).value ??
        const <
          String,
          Set<String>
        >{}; // empty-ok: no own role is held before the assignments are read
    final own = [
      for (final r in widget.roles)
        if (r.own != null) r.own!,
    ];
    int holders(DeskRole r) {
      final base = r.base;
      if (base != null) {
        return people.where((m) => permissionRoleOf(m) == base).length;
      }
      final id = r.own?.id;
      return people
          .where((m) => assignments[m.id]?.contains(id) ?? false)
          .length;
    }

    final wanted = _inAddress() ?? _chosen;
    final chosen =
        widget.roles.where((r) => r.id == wanted).firstOrNull ??
        widget.roles.first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FocusTraversalGroup(
          child: SizedBox(
            width: KitMetrics.choiceListWidth,
            child: ListView(
              key: const ValueKey('roles-desk-list'),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                for (final r in widget.roles)
                  ListTile(
                    key: ValueKey('roles-desk-role-${r.id}'),
                    selected: r.id == chosen.id,
                    title: Text(r.name),
                    subtitle: Text(l.rolesPeopleCount(holders(r))),
                    onTap: () => _choose(r.id),
                  ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: FocusTraversalGroup(
            child: _Permissions(
              key: ValueKey('roles-desk-shown-${chosen.id}'),
              role: chosen,
              widget: widget,
              people: people,
              own: own,
              assignments: assignments,
            ),
          ),
        ),
      ],
    );
  }
}

/// The chosen role's permissions, module by module.
class _Permissions extends StatelessWidget {
  const _Permissions({
    super.key,
    required this.role,
    required this.widget,
    required this.people,
    required this.own,
    required this.assignments,
  });

  final DeskRole role;
  final RolesDesk widget;
  final List<Member> people;
  final List<WorkspaceRole> own;
  final Map<String, Set<String>> assignments;

  /// The people who hold [permission], from the pieces of the gates.
  List<Member> _holders(WorkspacePermission permission) => [
    for (final m in people)
      if (grantedBy(
        accessSources(
          member: m,
          workspace: widget.workspace,
          roles: own,
          heldRoleIds: assignments[m.id] ?? const <String>{},
        ),
      ).contains(permission))
        m,
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final base = role.base;
    final granted = base != null
        ? permissionsForRole(base, widget.workspace)
        : role.own?.permissions ?? const <WorkspacePermission>{};
    // The owner holds everything, and nobody edits it; the own roles are
    // edited in their editor, with its rules.
    final editable =
        base != null && base != PermissionRole.owner && widget.canEdit;
    return ListView(
      padding: AppSpacing.gutterAll,
      children: [
        Row(
          children: [
            Expanded(child: Text(role.name, style: theme.textTheme.titleLarge)),
            if (base != null && base == widget.myRole)
              Chip(label: Text(l.rolesYourRole)),
            if (role.own case final ownRole?)
              OutlinedButton(
                key: const ValueKey('roles-desk-edit-own'),
                onPressed: () => widget.onEditOwn(ownRole),
                child: Text(l.rolesOwnRoleEdit),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(widget.intro, style: theme.textTheme.bodyMedium),
        for (final (module, permissions) in permissionsByModule()) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              permissionModuleName(l, module),
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final p in permissions)
            CheckboxListTile(
              key: ValueKey('perm-${role.id}-${p.wireName}'),
              controlAffinity: ListTileControlAffinity.leading,
              value: granted.contains(p),
              onChanged: editable
                  ? (_) => widget.onToggle(base, p, granted)
                  : null,
              title: Text(permissionLabel(l, p)),
              secondary: TextButton(
                key: ValueKey('perm-who-${p.wireName}'),
                onPressed: () => _showHolders(context, p),
                child: Text(l.rolesPeopleCount(_holders(p).length)),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _showHolders(BuildContext context, WorkspacePermission p) {
    final l = context.l10n;
    final holders = _holders(p);
    return showTask<void>(
      context,
      size: TaskSize.short,
      builder: (taskContext) => Consumer(
        builder: (context, ref, _) {
          final names =
              ref.watch(memberNamesProvider).value ??
              const {}; // empty-ok: an unread name shows blank
          return TaskChoice(
            title: l.rolesWhoHasTitle(permissionLabel(l, p)),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.rolesWhoHasExplain),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l.rolesPeopleCount(holders.length),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final m in holders)
                  ListTile(
                    key: ValueKey('perm-holder-${m.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(names[m.id] ?? ''),
                  ),
              ],
            ),
            actions: [
              FilledButton(
                key: const ValueKey('perm-who-close'),
                onPressed: () => Navigator.of(taskContext).pop(),
                child: Text(l.commonClose),
              ),
            ],
          );
        },
      ),
    );
  }
}
