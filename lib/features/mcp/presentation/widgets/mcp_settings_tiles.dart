// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/mcp_providers.dart';
import '../connect_assistant_screen.dart';

/// #1626/#1627/#1628 — the settings entries for assistants, in one
/// place so the settings screen grows by one line. Each shows only to
/// whom it can serve: a member of a workspace with `mcpAccess` on (their
/// own assistants), whoever the role matrix lets manage integrations (what it exposes), and this
/// database's administrators (approvals), whatever the workspace.
class McpSettingsTiles extends ConsumerWidget {
  const McpSettingsTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final on = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.mcpAccess);
    final manages = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.manageIntegrations);
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
        // #2145 — the journey to a first call, for every member here.
        if (on)
          ListTile(
            key: const ValueKey('settings-connect-assistant'),
            leading: const Icon(Icons.add_link),
            title: Text(l10n?.mcpConnectTitle ?? 'Connect an assistant'),
            onTap: () => context.push(connectAssistantRoute),
          ),
        // #1827 — offered before mcpAccess is on: that is its second step.
        if (manages)
          ListTile(
            key: const ValueKey('settings-assistant-setup'),
            leading: const Icon(Icons.checklist_outlined),
            title: Text(l10n?.assistantSetupTitle ?? 'Assistant setup'),
            onTap: () => context.push('/settings/assistant-setup'),
          ),
        if (on && manages)
          ListTile(
            key: const ValueKey('settings-assistant-policy'),
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(l10n?.mcpPolicyTitle ?? 'Assistant access'),
            onTap: () => context.push('/settings/assistants'),
          ),
        // #1827 B — only the instance operator gets an answer here.
        const _InstanceConsoleTile(),
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

/// #1827 B — shown only when the server answers the instance overview,
/// i.e. to the instance operator; asked once per visit.
class _InstanceConsoleTile extends ConsumerStatefulWidget {
  const _InstanceConsoleTile();

  @override
  ConsumerState<_InstanceConsoleTile> createState() =>
      _InstanceConsoleTileState();
}

class _InstanceConsoleTileState extends ConsumerState<_InstanceConsoleTile> {
  late final Future<bool> _operator = _isOperator();

  /// No answer — no backend, an older server, not the operator — is no
  /// tile, never an error on the account page.
  Future<bool> _isOperator() async {
    try {
      return await ref.read(assistantAccessProvider).instanceOverview() != null;
    } catch (e, st) {
      TraceLogger.instance.warn('mcp', 'instance console not offered',
          error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<bool>(
      future: _operator,
      builder: (context, snap) => snap.data == true
          ? ListTile(
              key: const ValueKey('settings-instance-assistants'),
              leading: const Icon(Icons.settings_input_antenna),
              title: Text(l10n?.instanceTitle ?? 'Installation: assistants'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/installation/assistants'),
            )
          : const SizedBox.shrink(),
    );
  }
}
