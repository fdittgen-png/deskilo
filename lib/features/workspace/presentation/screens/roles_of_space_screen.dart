// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1528 — the roles a workspace invented for itself.
//
// Distinct from `RolesScreen`, which is the matrix of the four the
// product decided (#513). This one lists what the SPACE added, and 0247
// refuses to let the two meet: a custom role may not take a built-in
// key, and an owner keeps every permission whatever the custom roles
// say.
//
// A role is never deleted here. It is put aside, because deleting one
// would take its assignments with it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../task_recorder/domain/action_registry.dart';
import '../../../task_recorder/presentation/recorder_seam.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_role.dart';
import '../../providers/workspace_providers.dart';
import '../../providers/workspace_roles_providers.dart';
import '../widgets/role_editor_sheet.dart';
import '../widgets/role_holders_section.dart';
import 'roles_screen_labels.dart';

class RolesOfSpaceScreen extends ConsumerStatefulWidget {
  const RolesOfSpaceScreen({super.key});

  static const Key addKey = Key('roles-of-space-add');

  static Key rowKeyFor(String roleKey) => ValueKey('roles-of-space-$roleKey');

  @override
  ConsumerState<RolesOfSpaceScreen> createState() => _RolesOfSpaceScreenState();
}

class _RolesOfSpaceScreenState extends ConsumerState<RolesOfSpaceScreen> {
  bool _saving = false;

  Future<void> _edit(WorkspaceRole? role) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final locale =
        workspace.defaultLocale.isEmpty ? 'en' : workspace.defaultLocale;
    var saved = false; // #1884 B — a sheet closed unsaved is a step too
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => RoleEditorSheet(
        initial: role,
        workspaceLocale: locale,
        saving: _saving,
        // #2085 — who holds it, given and taken back here too.
        holders: role != null &&
                ref
                    .read(enabledFeaturesSyncProvider)
                    .contains(WorkspaceFeature.roleAssignment)
            ? RoleHoldersSection(role: role, readOnly: role.builtin)
            : null,
        onSave: (draft) async {
          saved = true;
          Navigator.of(sheetContext).pop();
          await _save(workspace.id, draft, created: role == null);
        },
      ),
    );
    if (!saved && mounted) recordTaskStep(ref, RecorderActions.cancelRoleEdit);
  }

  Future<void> _save(String workspaceId, WorkspaceRole draft,
      {required bool created}) async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    final repository = ref.read(workspaceRolesRepositoryProvider);
    final attempt = recordTaskAttempt(ref, RecorderActions.saveRole, payload: {
      'role_change': draft.builtin ? 'renamed' : (created ? 'created' : 'edited'),
    }); // #1884 B
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace role update failed',
      // Its own sentence: the server refuses a built-in key and an
      // unknown permission, and an owner needs to know THAT.
      errorText: l10n.roleEditorSaveFailed,
      // #2085 — the Administrator is renamed, never redefined.
      action: () => observeTaskSetting(
          attempt,
          () => draft.builtin
              ? repository.renameAdministrator(workspaceId, draft.names)
              : repository.setRole(workspaceId, draft)),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    ref.invalidate(workspaceRolesProvider);
    AppSnack.success(context, l10n.billingSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final roles = ref.watch(workspaceRolesProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final locale = (workspace?.defaultLocale.isEmpty ?? true)
        ? 'en'
        : workspace!.defaultLocale;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rolesOfSpaceTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: RolesOfSpaceScreen.addKey,
        onPressed: _saving ? null : () => _edit(null),
        icon: const Icon(Icons.add),
        label: Text(l10n.rolesOfSpaceAdd),
      ),
      body: roles.when(
        loading: () => const LoadingView(),
        // A refusal already reached the trace and the snack through
        // runGuarded; a screen-sized sentence would be a second voice.
        error: (e, _) => const SizedBox.shrink(),
        data: (list) => ListView(
          padding: AppSpacing.gutterAll,
          children: [
            Text(
              l10n.rolesOfSpaceSubtitle,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (list.isEmpty)
              Text(
                l10n.rolesOfSpaceEmpty,
                style: theme.textTheme.bodyMedium,
              ),
            for (final role in list)
              ListTile(
                key: RolesOfSpaceScreen.rowKeyFor(role.key),
                contentPadding: EdgeInsets.zero,
                title: Text(role.nameIn(locale)),
                subtitle: Text(
                  [
                    if (role.builtin)
                      l10n.roleBuiltInSubtitle
                    else if (role.permissions.isEmpty)
                      '—'
                    else
                      role.permissions
                          .map((p) => permissionLabel(l10n, p))
                          .join(' · '),
                    if (!role.active)
                      l10n.rolesOfSpaceInactive,
                  ].join(' — '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _saving ? null : () => _edit(role),
              ),
            const SizedBox(height: kFabSafeBottom),
          ],
        ),
      ),
    );
  }
}
