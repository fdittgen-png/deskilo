// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — Connect an assistant: the one page a member follows from "I want
// my assistant to use DesKilo" to a first call. Three parts, top to
// bottom: what still stands in the way (each row names who acts and offers
// the one action that moves it), how to add DesKilo to each assistant with
// this server's address filled in, and a test that waits for the
// assistant's first call. Every fact is the server's answer; the page
// opens behind the workspace's mcpAccess flag and sends nothing on open.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/loading_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/assistant_setup_providers.dart';
import '../providers/mcp_providers.dart';
import 'widgets/connect_checklist_card.dart';
import 'widgets/connect_workspaces.dart';
import 'widgets/mcp_client_tabs.dart';
import 'widgets/mcp_connection_check.dart';

/// Where the page lives; every entry point pushes this.
const connectAssistantRoute = '/assistants/connect';

class ConnectAssistantScreen extends ConsumerStatefulWidget {
  const ConnectAssistantScreen({super.key});

  @override
  ConsumerState<ConnectAssistantScreen> createState() =>
      _ConnectAssistantScreenState();
}

class _ConnectAssistantScreenState
    extends ConsumerState<ConnectAssistantScreen> {
  bool _busy = false;

  Future<void> _run(String message, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await runGuarded(
      context,
      domain: 'mcp',
      message: message,
      action: action,
      errorText:
          context.l10n.mcpNextUnavailable,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ref
      ..invalidate(myDatabaseCapabilitiesProvider)
      ..invalidate(mcpAccessStatusProvider)
      ..invalidate(myMcpConnectionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scope = ref.watch(currentMcpContextProvider);
    // #2145 — the endpoint the installation publishes (0357), else the
    // one this app derives from its backend, as before.
    final published = ref.watch(mcpPublishedEndpointProvider).value?.resource;
    final url = published != null
        ? Uri.parse(published)
        : ref.watch(mcpConnectorUrlProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mcpConnectTitle),
      ),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n.mcpConnectIntro,
          ),
          const SizedBox(height: AppSpacing.md),
          _section(l10n.mcpConnectBeforeTitle),
          scope.when(
            loading: () => const LoadingView(),
            error: (_, _) => const ConnectUnavailable(),
            data: (captured) => captured == null
                ? Text(
                    key: const ValueKey('mcp-connect-no-workspace'),
                    l10n.assistantSetupNoWorkspace,
                  )
                : ConnectChecklistCard(
                    scope: captured,
                    busy: _busy,
                    run: _run,
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _section(l10n.mcpConnectWorkspacesTitle),
          Text(
            l10n.mcpConnectWorkspacesHint,
          ),
          ConnectWorkspaces(currentId: scope.value?.workspaceId),
          const SizedBox(height: AppSpacing.lg),
          _section(l10n.mcpConnectAddTitle),
          if (url == null)
            Text(
              key: const ValueKey('mcp-connect-no-connector'),
              l10n.assistantSetupNoConnector,
            )
          else
            McpClientTabs(connector: url),
          const SizedBox(height: AppSpacing.lg),
          _section(l10n.mcpConnectTestTitle),
          const McpConnectionTest(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.mcpConnectManageHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }


  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}
