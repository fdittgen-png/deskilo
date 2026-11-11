// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/workspace_providers.dart';

/// #3282 — the expert doors of "Configure workspace": the workspace's own
/// settings, the feature switches and the plan editor, each behind the
/// permission its page asks. Collapsed, below the guided tasks, so they do
/// not compete with the next useful step.
class SetupAdvancedSettings extends ConsumerWidget {
  const SetupAdvancedSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final permissions = ref.watch(myPermissionsProvider);
    // An unread feature set shows no plan door: never a door that refuses.
    final places =
        ref.watch(enabledFeaturesProvider).value?.contains(
          WorkspaceFeature.placeBooking,
        ) ??
        false;
    final doors = [
      if (permissions.contains(WorkspacePermission.workspaceSettings))
        (
          'setup-advanced-workspace-settings',
          Icons.business_outlined,
          l10n.workspaceSettingsTitle,
          '/workspace-settings',
        ),
      if (permissions.contains(WorkspacePermission.manageConfiguration))
        (
          'setup-advanced-features',
          Icons.toggle_on_outlined,
          l10n.featuresTitle,
          '/features',
        ),
      // #2137 — editing the plan is delegable through manageSites.
      if (places && permissions.contains(WorkspacePermission.manageSites))
        (
          'setup-advanced-editor',
          Icons.design_services_outlined,
          l10n.editorOpenTooltip,
          '/editor',
        ),
    ];
    if (doors.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      key: const ValueKey('setup-advanced-settings'),
      leading: const Icon(Icons.settings_outlined),
      title: Text(l10n.setupAdvancedSettings),
      children: [
        for (final (key, icon, label, route) in doors)
          ListTile(
            key: ValueKey(key),
            leading: Icon(icon),
            title: Text(label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(route),
          ),
      ],
    );
  }
}
