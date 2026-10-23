// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "what members may do": the least-privilege preset
// "members can book" grants exactly the member essentials (book, calendar,
// messages, own account) through the same command as the readiness card,
// permission by permission; nothing administrative is ever part of it. The
// preview lists what a member can do now, in the role matrix's own words,
// read from the stored matrix, so it changes only once the server has.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../application/grant_member_essentials.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/workspace_providers.dart';
import '../screens/roles_screen_labels.dart';
import 'setup_step_layout.dart';

class SetupMemberRightsStep extends ConsumerWidget {
  const SetupMemberRightsStep({super.key, required this.workspace});
  final Workspace workspace;

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'setup member rights preset failed',
      errorText: l10n.setupRightsApplyFailed,
      action: () => ref.read(memberEssentialsGrantProvider).grant(workspace.id),
    );
    // The matrix lives on the workspace row: the chain root reads it again
    // whether or not every permission made it.
    ref.invalidate(myWorkspacesProvider);
    if (ok && context.mounted) {
      AppSnack.success(context, l10n.readinessGrantMembersDone);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = permissionsForRole(PermissionRole.member, workspace);
    final canApply = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.manageRoles);
    final rolesOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.roleManagement);
    return SetupStepLayout(
      form: _PresetForm(
        applied: member.containsAll(memberEssentials),
        canApply: canApply,
        onApply: () => _apply(context, ref),
        onOpenRoles: rolesOn ? () => context.push('/roles') : null,
      ),
      preview: _MemberCanDo(granted: member),
    );
  }
}

class _PresetForm extends StatelessWidget {
  const _PresetForm({
    required this.applied,
    required this.canApply,
    required this.onApply,
    required this.onOpenRoles,
  });

  final bool applied;
  final bool canApply;
  final VoidCallback onApply;
  final VoidCallback? onOpenRoles;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.setupStepHint('member_rights')),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.setupRightsPresetTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.setupRightsPresetBody),
        for (final p in memberEssentials)
          ListTile(
            key: ValueKey('setup-rights-preset-${p.wireName}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check),
            title: Text(permissionLabel(l10n, p)),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (applied)
          Text(
            l10n.setupRightsApplied,
            key: const ValueKey('setup-rights-applied'),
            style: theme.textTheme.bodySmall,
          )
        else if (canApply)
          FilledButton(
            key: const ValueKey('setup-rights-apply'),
            onPressed: onApply,
            child: Text(l10n.readinessGrantMembers),
          )
        else
          Text(l10n.setupRightsNeedsManageRoles),
        if (onOpenRoles != null)
          TextButton(
            key: const ValueKey('setup-rights-open-roles'),
            onPressed: onOpenRoles,
            child: Text(l10n.setupRightsOpenRoles),
          ),
      ],
    );
  }
}

/// What a plain member holds under the stored matrix, in its words.
class _MemberCanDo extends StatelessWidget {
  const _MemberCanDo({required this.granted});
  final Set<WorkspacePermission> granted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // In the matrix's order, so the preview reads like the Roles screen.
    final shown = [
      for (final p in WorkspacePermission.values)
        if (granted.contains(p)) p,
    ];
    return Column(
      key: const ValueKey('setup-rights-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.setupRightsPreviewTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l10n.setupRightsPreviewNone,
              key: const ValueKey('setup-rights-preview-none'),
            ),
          ),
        for (final p in shown)
          ListTile(
            key: ValueKey('setup-rights-can-${p.wireName}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline),
            title: Text(permissionLabel(l10n, p)),
          ),
        if (!holdsOnlyEverydayPermissions(granted))
          InlineBanner(
            key: const ValueKey('setup-rights-preview-admin'),
            icon: Icons.admin_panel_settings_outlined,
            text: l10n.setupRightsPreviewAdmin,
          ),
      ],
    );
  }
}
