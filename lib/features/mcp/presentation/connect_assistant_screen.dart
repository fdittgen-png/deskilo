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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/domain/database_capabilities.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/instance_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/connect_checklist.dart';
import '../domain/mcp_context.dart';
import '../providers/assistant_setup_providers.dart';
import '../providers/mcp_providers.dart';
import 'confirm_identity.dart';
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
          AppLocalizations.of(context)?.mcpNextUnavailable ??
          'The server could not answer. Nothing is assumed; try again later.',
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
    final l10n = AppLocalizations.of(context);
    final scope = ref.watch(currentMcpContextProvider);
    final url = ref.watch(mcpConnectorUrlProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.mcpConnectTitle ?? 'Connect an assistant'),
      ),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n?.mcpConnectIntro ??
                'Let Claude, ChatGPT or another assistant check and book '
                    'things for you in DesKilo. It acts as you, only in the '
                    'workspaces and for the actions you approve.',
          ),
          const SizedBox(height: AppSpacing.md),
          _section(l10n?.mcpConnectBeforeTitle ?? 'Before you connect'),
          scope.when(
            loading: () => const LoadingView(),
            error: (_, _) => _unavailable(l10n),
            data: (captured) => captured == null
                ? Text(
                    key: const ValueKey('mcp-connect-no-workspace'),
                    l10n?.assistantSetupNoWorkspace ??
                        'Select a workspace first.',
                  )
                : _checklist(l10n, captured),
          ),
          const SizedBox(height: AppSpacing.lg),
          _section(l10n?.mcpConnectWorkspacesTitle ?? 'Your workspaces'),
          Text(
            l10n?.mcpConnectWorkspacesHint ??
                'Each workspace decides for itself. When your assistant '
                    'asks, you choose among the ready ones.',
          ),
          _workspaces(l10n, scope.value?.workspaceId),
          const SizedBox(height: AppSpacing.lg),
          _section(l10n?.mcpConnectAddTitle ?? 'Add DesKilo to your assistant'),
          if (url == null)
            Text(
              key: const ValueKey('mcp-connect-no-connector'),
              l10n?.assistantSetupNoConnector ?? 'This app runs without a server, so there is no connector URL.',
            )
          else
            McpClientTabs(connector: url),
          const SizedBox(height: AppSpacing.lg),
          _section(l10n?.mcpConnectTestTitle ?? 'Check that it works'),
          const McpConnectionTest(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n?.mcpConnectManageHint ??
                'To see what an assistant did or to disconnect it, open '
                    'Assistants.',
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

  Widget _unavailable(AppLocalizations? l10n) => InlineBanner(
    key: const ValueKey('mcp-connect-unavailable'),
    icon: Icons.cloud_off_outlined,
    severity: InlineBannerSeverity.error,
    text:
        l10n?.mcpNextUnavailable ??
        'The server could not answer. Nothing is assumed; try again later.',
  );

  /// #2145 — every workspace of this installation the person belongs
  /// to, each with its own state: one is never the stand-in for another.
  Widget _workspaces(AppLocalizations? l10n, String? currentId) {
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
      error: (_, _) => _unavailable(l10n),
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
        return Column(children: [for (final r in rows) _workspaceRow(l10n, r)]);
      },
    );
  }

  Widget _workspaceRow(AppLocalizations? l10n, WorkspaceAssistantRow r) {
    final theme = Theme.of(context);
    final (icon, color, text) = switch (r.state) {
      WorkspaceAssistantState.connected => (
        Icons.check_circle,
        theme.colorScheme.primary,
        l10n?.mcpConnectWsConnected ??
            'Connected — an assistant may act for you here.',
      ),
      WorkspaceAssistantState.ready => (
        Icons.radio_button_unchecked,
        theme.colorScheme.primary,
        l10n?.mcpConnectWsReady ??
            'Ready — choose it when your assistant asks.',
      ),
      WorkspaceAssistantState.notOffered => (
        Icons.hourglass_top,
        theme.colorScheme.tertiary,
        l10n?.mcpConnectWsNotOffered ??
            'Assistants are on, but nothing is offered to your role yet. A '
                'workspace administrator decides.',
      ),
      WorkspaceAssistantState.off => (
        Icons.block,
        theme.colorScheme.outline,
        l10n?.mcpConnectWsOff ??
            'Assistants are off in this workspace. A workspace administrator '
                'turns them on in Assistant setup.',
      ),
      WorkspaceAssistantState.unknown => (
        Icons.more_horiz,
        theme.colorScheme.outline,
        l10n?.mcpConnectWsUnknown ??
            'Shown once your access to assistants is approved.',
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
            r.current
                ? '${l10n?.mcpConnectWorkspaceSelected ?? 'Selected workspace'} · $text'
                : text,
          ),
        ),
        if (r.action == WorkspaceRowAction.openSetup)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: ValueKey('mcp-connect-ws-${r.id}-setup'),
              onPressed: () => context.push('/settings/assistant-setup'),
              child: Text(l10n?.mcpConnectOpenSetup ?? 'Open assistant setup'),
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
              child: Text(
                l10n?.mcpConnectSwitchWorkspace ?? 'Switch to this workspace',
              ),
            ),
          ),
      ],
    );
  }

  Widget _checklist(AppLocalizations? l10n, McpContextRef scope) {
    final status = ref.watch(mcpAccessStatusProvider(scope));
    final caps = ref.watch(myDatabaseCapabilitiesProvider);
    final who = ref.watch(instanceResponsiblesProvider).value;
    final manages = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.manageIntegrations);
    final now = ref.watch(clockProvider).now();
    return status.when(
      loading: () => const LoadingView(),
      error: (_, _) => _unavailable(l10n),
      data: (s) {
        final list = ConnectChecklist.derive(
          status: s,
          capabilities: caps.value,
          now: now,
          isOperator: who?.isOperator ?? false,
          canManageIntegrations: manages,
          workspaceOn: ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.mcpAccess),
        );
        final operators = [
          for (final p in [...?who?.owners, ...?who?.delegates])
            if (p.name.isNotEmpty) p.name,
        ];
        return Card(
          key: const ValueKey('mcp-connect-checklist'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in list.items)
                  _row(l10n, item, operators, list.accessExpiresSoon),
                if (list.next == null)
                  InlineBanner(
                    key: const ValueKey('mcp-connect-all-done'),
                    icon: Icons.check_circle_outline,
                    severity: InlineBannerSeverity.info,
                    text:
                        l10n?.mcpConnectAllDone ??
                        'Everything is ready. Test the connection below.',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(
    AppLocalizations? l10n,
    ConnectItem item,
    List<String> operators,
    bool expiresSoon,
  ) {
    final theme = Theme.of(context);
    final (icon, color) = switch (item.state) {
      ConnectState.done => (Icons.check_circle, theme.colorScheme.primary),
      ConnectState.todo => (
        Icons.radio_button_unchecked,
        theme.colorScheme.primary,
      ),
      ConnectState.waiting => (Icons.hourglass_top, theme.colorScheme.tertiary),
      ConnectState.blocked => (Icons.more_horiz, theme.colorScheme.outline),
      ConnectState.unavailable => (
        Icons.cloud_off_outlined,
        theme.colorScheme.error,
      ),
    };
    final action = _action(l10n, item, operators);
    return Column(
      key: ValueKey('mcp-connect-step-${item.step.name}-${item.state.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: color),
          title: Text(connectStepTitle(l10n, item.step)),
          subtitle: Text(
            connectStepDetail(
              l10n,
              item,
              operators: operators,
              expiresSoon: expiresSoon,
            ),
          ),
        ),
        if (action != null)
          Align(alignment: Alignment.centerRight, child: action),
      ],
    );
  }

  Widget? _action(
    AppLocalizations? l10n,
    ConnectItem item,
    List<String> operators,
  ) {
    Widget button(String label, VoidCallback onPressed) => TextButton(
      key: ValueKey('mcp-connect-action-${item.step.name}-${item.action.name}'),
      onPressed: _busy ? null : onPressed,
      child: Text(label),
    );
    final access = ref.read(assistantAccessProvider);
    return switch (item.action) {
      ConnectAction.none || ConnectAction.addConnector => null,
      ConnectAction.linkGoogle => button(
        l10n?.mcpStatusLinkGoogle ?? 'Link Google',
        () => context.push('/linked-accounts'),
      ),
      ConnectAction.signInWithGoogle => button(
        l10n?.mcpStatusSignInGoogle ?? 'Sign in with Google',
        () => _run('google sign-in failed', access.signInWithGoogle),
      ),
      ConnectAction.confirmIdentity => button(
        l10n?.mcpStatusConfirmIdentity ?? 'Confirm my identity',
        () => confirmAssistantIdentity(context, ref),
      ),
      ConnectAction.requestAccess => button(
        l10n?.mcpConsentRequestEligibility ?? 'Ask for approval',
        () => _run('eligibility request failed', access.requestEligibility),
      ),
      ConnectAction.openSetup => button(
        l10n?.mcpConnectOpenSetup ?? 'Open assistant setup',
        () => context.push('/settings/assistant-setup'),
      ),
      ConnectAction.openInstallation => button(
        l10n?.mcpConnectOpenInstallation ?? 'Open the installation console',
        () => context.push('/installation/assistants'),
      ),
      // No conversation reaches the operator from a workspace (their
      // account id is not shown to members), so the request is copied
      // for whichever channel the person uses to reach them.
      ConnectAction.askOperator => button(
        l10n?.mcpConnectCopyRequest ?? 'Copy a request to send',
        () async {
          await Clipboard.setData(
            ClipboardData(
              text:
                  l10n?.mcpConnectOperatorRequest ??
                  'Hello, could you switch assistants on for our DesKilo '
                      'server? It is under Settings → Installation: '
                      'assistants. Thank you.',
            ),
          );
          if (mounted) {
            AppSnack.success(context, l10n?.mcpConnectCopied ?? 'Copied.');
          }
        },
      ),
    };
  }
}

String connectStepTitle(AppLocalizations? l10n, ConnectStep step) =>
    switch (step) {
      ConnectStep.google => l10n?.mcpConnectStepGoogle ?? 'Google sign-in',
      ConnectStep.identity =>
        l10n?.mcpConnectStepIdentity ?? 'Your identity on this server',
      ConnectStep.access =>
        l10n?.mcpConnectStepAccess ?? 'Your access to assistants',
      ConnectStep.workspace =>
        l10n?.mcpConnectStepWorkspace ?? 'This workspace offers assistants',
      ConnectStep.server =>
        l10n?.mcpConnectStepServer ?? 'Assistants switched on for this server',
      ConnectStep.connect =>
        l10n?.mcpConnectStepConnect ?? 'DesKilo added to your assistant',
    };

/// The state of [item] in words, and who acts when it is someone else.
String connectStepDetail(
  AppLocalizations? l10n,
  ConnectItem item, {
  List<String> operators = const [],
  bool expiresSoon = false,
}) {
  final days = item.expiresInDays;
  if (item.state == ConnectState.done) {
    if (item.step == ConnectStep.access && days != null) {
      return expiresSoon
          ? (l10n?.mcpConnectAccessExpiresSoon(days) ??
                'Approved — expires in $days days. Ask for approval again '
                    'once it lapses.')
          : (l10n?.mcpConnectAccessExpiresIn(days) ??
                'Approved — $days days left.');
    }
    return l10n?.mcpConnectDone ?? 'Done';
  }
  if (item.roleDenied) {
    return l10n?.mcpConnectRoleDenied ??
        'Nothing is offered to your role here. A workspace administrator '
            'decides what each role may do.';
  }
  return switch (item.state) {
    ConnectState.todo => switch (item.step) {
      ConnectStep.connect =>
        l10n?.mcpConnectTodoConnect ??
            'To do — you: follow the steps for your assistant below.',
      _ => l10n?.mcpConnectTodoYou ?? 'To do — you.',
    },
    ConnectState.waiting => switch (item.actor) {
      ConnectActor.workspaceAdmin =>
        l10n?.mcpConnectWaitingWorkspaceAdmin ??
            'Waiting for a workspace administrator to offer assistants here.',
      ConnectActor.databaseAdministrator =>
        l10n?.mcpConnectWaitingDatabaseAdmin ??
            'Waiting for a database administrator to approve your request.',
      ConnectActor.operator =>
        operators.isEmpty
            ? (l10n?.mcpConnectWaitingOperatorUnknown ??
                  'Waiting for the server\'s operator, who is not named yet.')
            : (l10n?.mcpConnectWaitingOperator(operators.join(', ')) ??
                  'Waiting for the server\'s operator: ${operators.join(', ')}.'),
      ConnectActor.you => l10n?.mcpConnectTodoYou ?? 'To do — you.',
    },
    ConnectState.blocked =>
      l10n?.mcpStateAfterPrevious ?? 'After the step above',
    ConnectState.unavailable =>
      l10n?.mcpConnectUnavailable ?? 'Could not be checked right now.',
    ConnectState.done => l10n?.mcpConnectDone ?? 'Done',
  };
}
