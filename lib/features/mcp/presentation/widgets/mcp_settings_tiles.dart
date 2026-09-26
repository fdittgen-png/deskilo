// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// #1626/#1627/#1628 — the settings entries for assistants, in one
/// place so the settings screen grows by one line. Each shows only to
/// whom it can serve: a member of a workspace with `mcpAccess` on (their
/// own assistants), that workspace's owner (what it exposes), and this
/// database's administrators (approvals), whatever the workspace.
class McpSettingsTiles extends ConsumerWidget {
  const McpSettingsTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final on = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.mcpAccess);
    final owner = ref.watch(myMemberProvider).value?.actsAsOwner ?? false;
    final admin =
        ref
            .watch(myDatabaseCapabilitiesProvider)
            .value
            ?.databaseAdministrator ??
        false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (on)
          ListTile(
            key: const ValueKey('settings-assistants'),
            leading: const Icon(Icons.smart_toy_outlined),
            title: Text(l10n?.mcpAssistantsTitle ?? 'Assistants'),
            onTap: () => context.push('/assistants'),
          ),
        if (on && owner)
          ListTile(
            key: const ValueKey('settings-assistant-policy'),
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(l10n?.mcpPolicyTitle ?? 'Assistant access'),
            onTap: () => context.push('/settings/assistants'),
          ),
        if (admin)
          ListTile(
            key: const ValueKey('settings-assistant-review'),
            leading: const Icon(Icons.how_to_reg_outlined),
            title: Text(l10n?.mcpReviewTitle ?? 'Assistant approvals'),
            onTap: () => context.push('/database/assistant-approvals'),
          ),
      ],
    );
  }
}
