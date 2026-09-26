// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/database_capabilities.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/mcp_connection.dart';
import '../providers/mcp_providers.dart';
import 'mcp_operation_labels.dart';

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
      ..invalidate(myMcpConnectionsProvider);
  }

  Future<void> _disconnect(AppLocalizations? l10n, McpConnectionInfo c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n?.mcpDisconnectTitle(c.clientName) ??
              'Disconnect ${c.clientName}?',
        ),
        content: Text(
          l10n?.mcpDisconnectBody ??
              'The assistant loses access to every workspace on this database. What it already '
                  'read is not taken back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.mcpCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('mcp-disconnect-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.mcpDisconnect ?? 'Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      'assistant disconnect failed',
      () => ref.read(assistantAccessProvider).disconnect(c.clientId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final caps = ref.watch(myDatabaseCapabilitiesProvider);
    final connections = ref.watch(myMcpConnectionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.mcpAssistantsTitle ?? 'Assistants')),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          caps.when(
            loading: () => const LoadingView(),
            error: (e, _) => _banner(
              'mcp-assistants-unavailable',
              l10n?.mcpAssistantsUnavailable ??
                  'Your assistant access could not be loaded. Try again later.',
              Icons.cloud_off_outlined,
              InlineBannerSeverity.error,
            ),
            data: (c) => _eligibility(l10n, c),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n?.mcpConnectedTitle ?? 'Connected assistants',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          connections.when(
            loading: () => const LoadingView(),
            error: (e, _) => _banner(
              'mcp-connections-unavailable',
              l10n?.mcpAssistantsUnavailable ??
                  'Your assistant access could not be loaded. Try again later.',
              Icons.cloud_off_outlined,
              InlineBannerSeverity.error,
            ),
            data: (list) => list.isEmpty
                ? Text(
                    key: const ValueKey('mcp-connections-none'),
                    l10n?.mcpConnectedNone ??
                        'No assistant is connected. Connect one from the assistant itself.',
                  )
                : Column(
                    children: [for (final c in list) _connection(l10n, c)],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _eligibility(AppLocalizations? l10n, DatabaseCapabilities c) {
    final (text, severity) = switch (c.eligibility) {
      McpEligibility.eligible => (
        l10n?.mcpEligibleYes ?? 'This database allows you to use assistants.',
        InlineBannerSeverity.info,
      ),
      McpEligibility.requested => (
        l10n?.mcpEligibleRequested ??
            'You asked for approval. A database administrator will review it.',
        InlineBannerSeverity.info,
      ),
      McpEligibility.expired => (
        l10n?.mcpEligibleExpired ??
            'Your approval expired. Ask again to keep using assistants.',
        InlineBannerSeverity.error,
      ),
      McpEligibility.noIdentity => (
        l10n?.mcpEligibleNoIdentity ??
            'Your account is not linked to a verified identity on this database.',
        InlineBannerSeverity.error,
      ),
      McpEligibility.notRequested => (
        l10n?.mcpEligibleNot ??
            'This database has not approved assistants for you.',
        InlineBannerSeverity.info,
      ),
      _ => (
        l10n?.mcpAssistantsUnavailable ??
            'Your assistant access could not be loaded. Try again later.',
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
              l10n?.mcpConsentRequestEligibility ?? 'Ask for approval',
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
              l10n?.mcpEligibleWithdraw ??
                  'Give up assistant access on this database',
            ),
          ),
      ],
    );
  }

  Widget _connection(AppLocalizations? l10n, McpConnectionInfo c) => Card(
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
              l10n?.mcpConnectedNoWorkspace ??
                  'No workspace: this assistant can do nothing here.',
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
                tooltip: l10n?.mcpRemoveWorkspace ?? 'Remove this workspace',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _busy
                    ? null
                    : () => _run(
                        'workspace removal failed',
                        () => ref
                            .read(assistantAccessProvider)
                            .removeWorkspace(c.clientId, w.id),
                      ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: ValueKey('mcp-disconnect-${c.clientId}'),
              onPressed: _busy ? null : () => _disconnect(l10n, c),
              child: Text(l10n?.mcpDisconnect ?? 'Disconnect'),
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
