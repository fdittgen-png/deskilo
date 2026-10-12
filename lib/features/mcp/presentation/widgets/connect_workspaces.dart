// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../auth/domain/database_capabilities.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/connect_checklist.dart';
import '../../providers/assistant_setup_providers.dart';
import '../../providers/mcp_providers.dart';

/// The "could not ask the server" line of the Connect page.
class ConnectUnavailable extends StatelessWidget {
  const ConnectUnavailable({super.key});

  @override
  Widget build(BuildContext context) => InlineBanner(
    key: const ValueKey('mcp-connect-unavailable'),
    icon: Icons.cloud_off_outlined,
    text: context.l10n.mcpNextUnavailable,
  );
}

/// #2145 — every workspace of this installation the person belongs
/// to, each with its own state: one is never the stand-in for another.
class ConnectWorkspaces extends ConsumerWidget {
  const ConnectWorkspaces({super.key, required this.currentId});

  final String? currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myWorkspacesProvider);
    final caps = ref.watch(myDatabaseCapabilitiesProvider).value;
    final approved = caps?.eligibility == McpEligibility.eligible;
    final options = approved ? ref.watch(myMcpConsentOptionsProvider) : null;
    final connections = ref.watch(myMcpConnectionsProvider).value;
    final manages = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.manageIntegrations);
    final offered = options?.value;
    return mine.when(
      loading: () => const LoadingView(),
      error: (_, _) => const ConnectUnavailable(),
      data: (list) {
        final rows = deriveWorkspaceRows(
          workspaces: [
            for (final w in list)
              (
                id: w.id,
                name: w.name,
                mcpOn: effectiveFeatures(resolveEnabledFeatures(w.featureFlags))
                    .contains(WorkspaceFeature.mcpAccess),
              ),
          ],
          offered: offered == null || !offered.eligible
              ? null
              : {for (final w in offered.workspaces) w.id: w.operations.length},
          connected: connections == null
              ? null
              : {
                  for (final c in connections)
                    for (final w in c.workspaces) w.id,
                },
          currentId: currentId,
          canManageCurrent: manages,
        );
        return Column(children: [for (final r in rows) _WorkspaceRow(r)]);
      },
    );
  }
}

class _WorkspaceRow extends ConsumerWidget {
  const _WorkspaceRow(this.r);

  final WorkspaceAssistantRow r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (icon, color, text) = switch (r.state) {
      WorkspaceAssistantState.connected => (
        Icons.check_circle,
        theme.colorScheme.primary,
        l10n.mcpConnectWsConnected,
      ),
      WorkspaceAssistantState.ready => (
        Icons.radio_button_unchecked,
        theme.colorScheme.primary,
        l10n.mcpConnectWsReady,
      ),
      WorkspaceAssistantState.notOffered => (
        Icons.hourglass_top,
        theme.colorScheme.tertiary,
        l10n.mcpConnectWsNotOffered,
      ),
      WorkspaceAssistantState.off => (
        Icons.block,
        theme.colorScheme.outline,
        l10n.mcpConnectWsOff,
      ),
      WorkspaceAssistantState.unknown => (
        Icons.more_horiz,
        theme.colorScheme.outline,
        l10n.mcpConnectWsUnknown,
      ),
    };
    return Column(
      key: ValueKey('mcp-connect-ws-${r.id}-${r.state.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: color),
          title: Text(r.name),
          subtitle: Text(
            r.current ? '${l10n.mcpConnectWorkspaceSelected} · $text' : text,
          ),
        ),
        if (r.action == WorkspaceRowAction.openSetup)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: ValueKey('mcp-connect-ws-${r.id}-setup'),
              onPressed: () => context.push('/settings/assistant-setup'),
              child: Text(l10n.mcpConnectOpenSetup),
            ),
          ),
        // Another workspace's setup is reached from inside it: switch,
        // and this page answers for it (and offers its setup to whoever
        // manages its integrations).
        if (r.action == WorkspaceRowAction.switchTo)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: ValueKey('mcp-connect-ws-${r.id}-switch'),
              onPressed: () =>
                  ref.read(activeWorkspaceIdProvider.notifier).select(r.id),
              child: Text(l10n.mcpConnectSwitchWorkspace),
            ),
          ),
      ],
    );
  }
}
