// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/database_capabilities.dart';
import '../../auth/providers/auth_providers.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/mcp_connection.dart';
import '../providers/mcp_providers.dart';
import 'connect_assistant_screen.dart';
import 'mcp_operation_labels.dart';
import 'widgets/mcp_access_status_card.dart';
import 'widgets/mcp_usage_cards.dart';

/// #1628 — the person's own assistant access on this database: whether
/// the database approved them, and each connected assistant with the
/// workspaces it may use. Removing one workspace leaves the others;
/// disconnecting ends the assistant's access here and is confirmed first.
/// Connecting starts from the assistant, which sends the person to the
/// consent screen (#1615); nothing here holds or shows a token.
class AssistantsScreen extends ConsumerStatefulWidget {
  const AssistantsScreen({super.key});

  @override
  ConsumerState<AssistantsScreen> createState() => _AssistantsScreenState();
}

class _AssistantsScreenState extends ConsumerState<AssistantsScreen> {
  bool _busy = false;

  Future<void> _run(String message, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await runGuarded(context, domain: 'mcp', message: message, action: action);
    if (!mounted) return;
    setState(() => _busy = false);
    ref
      ..invalidate(myDatabaseCapabilitiesProvider)
      ..invalidate(myMcpConnectionsProvider)
      ..invalidate(myMcpUsageProvider)
      ..invalidate(mcpAccessStatusProvider)
      ..invalidate(connectedMcpOverviewProvider);
  }

  Future<void> _disconnect(AppLocalizations l10n, McpConnectionInfo c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.mcpDisconnectTitle(c.clientName),
        ),
        content: Text(
          l10n.mcpDisconnectBody,
        ),
        actions: [
          TextButton(
            key: const ValueKey('assistants-mcp-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.mcpCancel),
          ),
          FilledButton(
            key: const ValueKey('mcp-disconnect-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.mcpDisconnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      'assistant disconnect failed',
      () => ref.read(assistantAccessProvider).disconnect(c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final caps = ref.watch(myDatabaseCapabilitiesProvider);
    final connections = ref.watch(myMcpConnectionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mcpAssistantsTitle)),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          // #2145 — the guided way in: steps per assistant and a test.
          if (ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.mcpAccess)) ...[
            FilledButton.icon(
              key: const ValueKey('mcp-open-connect'),
              icon: const Icon(Icons.add_link),
              label: Text(l10n.mcpConnectTitle),
              onPressed: () => context.push(connectAssistantRoute),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // #1625 — the six facts and the next step, then the eligibility
          // actions they explain.
          const McpAccessStatusCard(),
          const SizedBox(height: AppSpacing.md),
          caps.when(
            loading: () => const LoadingView(),
            error: (e, _) => _banner(
              'mcp-assistants-unavailable',
              l10n.mcpAssistantsUnavailable,
              Icons.cloud_off_outlined,
              InlineBannerSeverity.error,
            ),
            data: (c) => _eligibility(l10n, c),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.mcpConnectedTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          connections.when(
            loading: () => const LoadingView(),
            error: (e, _) => _banner(
              'mcp-connections-unavailable',
              l10n.mcpAssistantsUnavailable,
              Icons.cloud_off_outlined,
              InlineBannerSeverity.error,
            ),
            data: (list) => list.isEmpty
                ? Text(
                    key: const ValueKey('mcp-connections-none'),
                    l10n.mcpConnectedNone,
                  )
                : Column(
                    children: [for (final c in list) _connection(l10n, c)],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const McpMyUsageSection(),
        ],
      ),
    );
  }

  Widget _eligibility(AppLocalizations l10n, DatabaseCapabilities c) {
    final (text, severity) = switch (c.eligibility) {
      McpEligibility.eligible => (
        l10n.mcpEligibleYes,
        InlineBannerSeverity.info,
      ),
      McpEligibility.requested => (
        l10n.mcpEligibleRequested,
        InlineBannerSeverity.info,
      ),
      McpEligibility.expired => (
        l10n.mcpEligibleExpired,
        InlineBannerSeverity.error,
      ),
      McpEligibility.noIdentity => (
        l10n.mcpEligibleNoIdentity,
        InlineBannerSeverity.error,
      ),
      McpEligibility.notRequested => (
        l10n.mcpEligibleNot,
        InlineBannerSeverity.info,
      ),
      _ => (
        l10n.mcpAssistantsUnavailable,
        InlineBannerSeverity.error,
      ),
    };
    final canAsk =
        c.eligibility == McpEligibility.notRequested ||
        c.eligibility == McpEligibility.expired;
    final canWithdraw =
        c.eligibility == McpEligibility.requested ||
        c.eligibility == McpEligibility.eligible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _banner(
          'mcp-eligibility-${c.eligibility.name}',
          text,
          Icons.verified_user_outlined,
          severity,
        ),
        if (canAsk)
          OutlinedButton(
            key: const ValueKey('mcp-eligibility-request'),
            onPressed: _busy
                ? null
                : () => _run(
                    'eligibility request failed',
                    () =>
                        ref.read(assistantAccessProvider).requestEligibility(),
                  ),
            child: Text(
              l10n.mcpConsentRequestEligibility,
            ),
          ),
        if (canWithdraw)
          TextButton(
            key: const ValueKey('mcp-eligibility-withdraw'),
            onPressed: _busy
                ? null
                : () => _run(
                    'eligibility withdrawal failed',
                    () =>
                        ref.read(assistantAccessProvider).withdrawEligibility(),
                  ),
            child: Text(
              l10n.mcpEligibleWithdraw,
            ),
          ),
      ],
    );
  }

  Widget _connection(AppLocalizations l10n, McpConnectionInfo c) => Card(
    key: ValueKey('mcp-connection-${c.clientId}'),
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(c.clientName, style: Theme.of(context).textTheme.titleSmall),
          if (c.workspaces.isEmpty)
            Text(
              l10n.mcpConnectedNoWorkspace,
            ),
          for (final w in c.workspaces)
            ListTile(
              key: ValueKey('mcp-connection-${c.clientId}-${w.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(w.name),
              subtitle: Text(
                w.operations
                    .map((op) => mcpOperationLabel(l10n, op))
                    .join(', '),
              ),
              trailing: IconButton(
                key: ValueKey('mcp-remove-${c.clientId}-${w.id}'),
                tooltip: l10n.mcpRemoveWorkspace,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _busy
                    ? null
                    : () => _run(
                        'workspace removal failed',
                        () => ref
                            .read(assistantAccessProvider)
                            .removeWorkspace(c, w.id),
                      ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: ValueKey('mcp-disconnect-${c.clientId}'),
              onPressed: _busy ? null : () => _disconnect(l10n, c),
              child: Text(l10n.mcpDisconnect),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _banner(
    String key,
    String text,
    IconData icon,
    InlineBannerSeverity severity,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: InlineBanner(
      key: ValueKey(key),
      icon: icon,
      severity: severity,
      text: text,
    ),
  );
}
