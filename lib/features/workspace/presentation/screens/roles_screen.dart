// SPDX-License-Identifier: AGPL-3.0-or-later
import 'roles_screen_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/workspace_providers.dart';

/// #513 — the CENTRAL role management: one matrix, roles × permissions.
///
///  * The OWNER row is locked — owners always hold everything.
///  * Whoever holds [WorkspacePermission.manageRoles] edits the other
///    rows (co-owner may hold LESS than an owner; the owner decides).
///  * Everyone else with any permission reads the matrix — their own
///    role highlighted — but cannot change a thing.
class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});


  String _roleLabel(AppLocalizations? l10n, PermissionRole role) =>
      switch (role) {
        PermissionRole.owner => l10n?.roleOwner ?? 'Owner',
        PermissionRole.coOwner => l10n?.memberCoOwnerChip ?? 'Co-owner',
        PermissionRole.admin => l10n?.roleAdmin ?? 'Admin',
        PermissionRole.member => l10n?.roleMember ?? 'Member',
      };

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required PermissionRole role,
    required WorkspacePermission permission,
    required Set<WorkspacePermission> current,
  }) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    // #1089 — what changed, not what the screen remembers. Sending the
    // recomputed list made every toggle a write of the WHOLE role, so a
    // permission somebody else granted or an owner removed while this
    // screen was open came back or vanished with the next tap here.
    final enabled = !current.contains(permission);
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'role permissions update failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        await ref.read(workspaceRepositoryProvider).setRolePermission(
              workspace.id,
              role.wireName,
              permission.wireName,
              enabled: enabled,
            );
        // The workspace CHAIN root — currentWorkspaceProvider derives
        // from it and would otherwise recompute from the stale list.
        ref.invalidate(myWorkspacesProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final me = ref.watch(myMemberProvider).value;
    final myPerms = ref.watch(myPermissionsProvider);
    final canEdit = myPerms.contains(WorkspacePermission.manageRoles);
    final myRole = me == null ? null : permissionRoleOf(me);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.rolesTitle ?? 'Role management'),
      ),
      body: ListView(
        padding: AppSpacing.lgAll,
        children: [
          Text(
            canEdit
                ? (l10n?.rolesIntroEditor ??
                    'The owner always holds every permission. Decide '
                        'here what the other roles may do — a co-owner '
                        'can hold less than an owner.')
                : (l10n?.rolesIntroReadOnly ??
                    'Read-only: these are the permissions each role '
                        'holds. Your role is highlighted.'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
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
                                _roleLabel(l10n, role),
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
                                    l10n?.rolesYourRole ?? 'Your role'),
                                visualDensity: VisualDensity.compact,
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
                          // #763 — height-capped: the dot's tap padding
                          // must not grow the dense matrix row.
                          title: SizedBox(
                            height: 24,
                            child: HelpDotTitle(
                              permissionLabel(l10n, permission),
                              switch (permission) {
                                WorkspacePermission.viewNegotiations ||
                                WorkspacePermission.manageNegotiations =>
                                  l10n?.helpHintMembersTipNegotiationTopic ??
                                      'Price negotiations',
                                _ => l10n?.helpHintMembersTip4Topic ??
                                    'Role management',
                              },
                              anchor: HelpAnchor.rolesMatrix,
                            ),
                          ),
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
