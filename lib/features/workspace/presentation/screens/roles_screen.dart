// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../task_recorder/domain/action_registry.dart';
import '../../../task_recorder/presentation/recorder_seam.dart';
import '../../domain/role_assignment.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../domain/workspace_role.dart';
import '../../providers/workspace_providers.dart';
import '../../providers/workspace_roles_providers.dart';
import '../widgets/role_editor_sheet.dart';
import 'roles_screen_labels.dart';

/// #513 — the CENTRAL role management: one matrix, roles × permissions.
///
///  * The OWNER row is locked — owners always hold everything.
///  * Whoever holds [WorkspacePermission.manageRoles] edits the other
///    rows (co-owner may hold LESS than an owner; the owner decides).
///  * Everyone else with any permission reads the matrix — their own
///    role highlighted — but cannot change a thing.
class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  static const Key ownRolesKey = Key('roles-own-roles');


  static const Key renameAdministratorKey = Key('roles-rename-administrator');

  String _roleLabel(
    AppLocalizations l10n,
    PermissionRole role, {
    required String administrator,
  }) =>
      switch (role) {
        PermissionRole.owner => l10n.roleOwner,
        PermissionRole.coOwner => l10n.memberCoOwnerChip,
        PermissionRole.admin => administrator,
        PermissionRole.member => l10n.baseRoleUser,
      };

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required PermissionRole role,
    required WorkspacePermission permission,
    required Set<WorkspacePermission> current,
  }) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    // #1089 — what changed, not what the screen remembers. Sending the
    // recomputed list made every toggle a write of the WHOLE role, so a
    // permission somebody else granted or an owner removed while this
    // screen was open came back or vanished with the next tap here.
    final enabled = !current.contains(permission);
    // #1884 B — the task recorder: which permission, for which built-in
    // role, which way; the attempt first, the real result after.
    final attempt = recordTaskAttempt(ref, RecorderActions.togglePermission,
        target: permission.wireName,
        payload: {'role_kind': role.wireName, 'switch_to': enabled ? 'on' : 'off'});
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'role permissions update failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        await observeTaskSetting(
            attempt,
            () => ref.read(workspaceRepositoryProvider).setRolePermission(
                  workspace.id,
                  role.wireName,
                  permission.wireName,
                  enabled: enabled,
                ));
        // The workspace CHAIN root — currentWorkspaceProvider derives
        // from it and would otherwise recompute from the stale list.
        ref.invalidate(myWorkspacesProvider);
      },
    );
  }

  /// #2085 — the owner renames the Administrator; what it may do stays
  /// in the matrix below.
  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    WorkspaceRole role,
  ) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final locale =
        workspace.defaultLocale.isEmpty ? 'en' : workspace.defaultLocale;
    final draft = await showModalBottomSheet<WorkspaceRole>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => RoleEditorSheet(
        initial: role,
        workspaceLocale: locale,
        onSave: (d) async => Navigator.of(sheetContext).pop(d),
      ),
    );
    if (draft == null) recordTaskStep(ref, RecorderActions.cancelRoleEdit);
    if (draft == null || !context.mounted) return;
    final attempt = recordTaskAttempt(ref, RecorderActions.saveRole,
        payload: {'role_change': 'renamed'}); // #1884 B
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'administrator rename failed',
      errorText: l10n.roleEditorSaveFailed,
      action: () => observeTaskSetting(
          attempt,
          () => ref
              .read(workspaceRolesRepositoryProvider)
              .renameAdministrator(workspace.id, draft.names)),
    );
    if (!ok) return;
    ref.invalidate(workspaceRolesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final me = ref.watch(myMemberProvider).value;
    final myPerms = ref.watch(myPermissionsProvider);
    final canEdit = myPerms.contains(WorkspacePermission.manageRoles);
    final myRole = me == null ? null : permissionRoleOf(me);
    final features = ref.watch(enabledFeaturesSyncProvider);
    // #2085 — one Roles entry: the space's own roles are reached from
    // here, by whoever defines them or gives them.
    final roles =
        ref.watch(workspaceRolesProvider).value ?? const <WorkspaceRole>[];
    final locale = Localizations.localeOf(context).languageCode;
    final administrator =
        administratorName(roles, locale, l10n.roleAdmin);
    final renameable = features.contains(WorkspaceFeature.roleAssignment) &&
            (me?.actsAsOwner ?? false)
        ? administratorRole(roles)
        : null;
    final ownRolesLink = features.contains(WorkspaceFeature.roleAssignment) &&
        features.contains(WorkspaceFeature.customRoles) &&
        ((me?.actsAsOwner ?? false) || canEdit);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rolesTitle),
        actions: [
          HelpDot(
            l10n.helpHintMembersTip4Topic,
            anchor: HelpAnchor.rolesMatrix,
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.lgAll,
        children: [
          Text(
            canEdit
                ? (l10n.rolesIntroEditor)
                : (l10n.rolesIntroReadOnly),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (ownRolesLink)
            Card(
              child: ListTile(
                key: RolesScreen.ownRolesKey,
                leading: const Icon(Icons.badge_outlined),
                title: Text(l10n.rolesOwnRolesLink),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/roles-of-this-space'),
              ),
            ),
          for (final role in PermissionRole.values) ...[
            Builder(builder: (context) {
              final granted = permissionsForRole(role, workspace);
              final locked = role == PermissionRole.owner || !canEdit;
              final mine = role == myRole;
              return Card(
                key: ValueKey('role-card-${role.wireName}'),
                shape: mine
                    ? RoundedRectangleBorder(
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                        borderRadius: AppRadius.lgAll,
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _roleLabel(l10n, role,
                                    administrator: administrator),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (mine)
                              Chip(
                                label: Text(
                                    l10n.rolesYourRole),
                                visualDensity: VisualDensity.compact,
                              ),
                            // #2085 — the owner renames the Administrator.
                            if (role == PermissionRole.admin &&
                                renameable != null)
                              IconButton(
                                key: renameAdministratorKey,
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: l10n.roleRenameAdministrator,
                                onPressed: () =>
                                    _rename(context, ref, renameable),
                              ),
                            if (role == PermissionRole.owner)
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: AppSpacing.sm),
                                child: Icon(Icons.lock_outline,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                      for (final permission in WorkspacePermission.values)
                        CheckboxListTile(
                          key: ValueKey(
                              'perm-${role.wireName}-${permission.wireName}'),
                          dense: true,
                          controlAffinity:
                              ListTileControlAffinity.leading,
                          value: granted.contains(permission),
                          onChanged: locked
                              ? null
                              : (_) => _toggle(context, ref,
                                  role: role,
                                  permission: permission,
                                  current: granted),
                          title: Text(permissionLabel(l10n, permission)),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
