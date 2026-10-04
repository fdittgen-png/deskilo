// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'confirm_identity.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/instance_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/assistant_setup.dart';
import '../application/mcp_onboarding_commands.dart';
import '../application/mcp_policy_editor.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_context.dart';
import '../providers/assistant_setup_providers.dart';
import '../providers/mcp_providers.dart';
import 'assistant_setup_labels.dart';
import 'connect_assistant_screen.dart';
import 'mcp_operation_labels.dart';

/// #1827 — Settings → Assistant setup: the steps that make assistants
/// work for the selected workspace, in order, each with its state, who
/// takes it and the one action the person looking may take. Opening the
/// screen changes nothing; every action is a button, and the server
/// checks the permission again on every call.
class AssistantSetupScreen extends ConsumerStatefulWidget {
  const AssistantSetupScreen({super.key});

  @override
  ConsumerState<AssistantSetupScreen> createState() =>
      _AssistantSetupScreenState();
}

class _AssistantSetupScreenState extends ConsumerState<AssistantSetupScreen> {
  bool _busy = false;

  Future<void> _run(
    McpContextRef scope,
    String message,
    Future<void> Function() action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    await runGuarded(context, domain: 'mcp', message: message, action: action);
    if (!mounted) return;
    setState(() => _busy = false);
    ref
      ..invalidate(myDatabaseCapabilitiesProvider)
      ..invalidate(mcpPolicyProvider(scope))
      ..invalidate(mcpAccessStatusProvider(scope))
      ..invalidate(assistantSetupProvider(scope));
  }

  /// Turns `mcpAccess` on for the workspace the checklist was read for —
  /// refused when the selection moved since, rather than switching
  /// another workspace's feature. #2145 — through 0360's
  /// `set_workspace_mcp_access`, which whoever manages integrations may
  /// call, against the value read; a change in between is reloaded.
  Future<void> _turnOn(McpContextRef scope) =>
      _run(scope, 'assistant setup feature switch failed', () async {
        final ws = ref.read(currentWorkspaceProvider).value;
        if (ws == null || ws.id != scope.workspaceId) {
          throw const McpContextSuperseded();
        }
        final outcome = await ref
            .read(mcpOnboardingCommandsProvider)
            .offerAssistants(ws.id);
        if (outcome == WorkspaceSwitchOutcome.stale && mounted) {
          AppSnack.info(
            context,
            AppLocalizations.of(context)?.assistantSetupStale ??
                'Someone changed the offer meanwhile. Review it and try '
                    'again.',
          );
        }
        ref.invalidate(myWorkspacesProvider);
      });

  /// Shows exactly what the recommended set changes, and saves it only
  /// when the person applies it.
  Future<void> _recommend(McpContextRef scope) async {
    final l10n = AppLocalizations.of(context);
    final McpPolicy policy;
    try {
      policy = await ref.read(mcpPolicyProvider(scope).future);
    } catch (e, st) {
      // trace-exempt: the step already reads "could not be asked"; the
      // snack says the same and nothing was sent.
      debugPrintStack(stackTrace: st, label: '$e');
      if (mounted) AppSnack.error(context, assistantSetupFailedText(l10n));
      return;
    }
    if (!mounted) return;
    final recommended = recommendedMcpOperations(policy.available);
    final added = recommended.difference(policy.operations);
    final removed = policy.operations.difference(recommended);
    final narrows = policy.targetCeiling != 'own';
    final unchanged =
        added.isEmpty && removed.isEmpty && !narrows && policy.enabled;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => _PreviewDialog(
        added: added,
        removed: removed,
        narrows: narrows,
        unchanged: unchanged,
      ),
    );
    if (apply != true || unchanged || !mounted) return;
    final draft = McpPolicyDraft.from(policy)
      ..enabled = true
      ..targetCeiling = 'own';
    draft.operations
      ..clear()
      ..addAll(recommended);
    PolicySaveResult? result;
    await _run(scope, 'assistant setup recommended policy failed', () async {
      result = await ref.read(mcpPolicyEditorProvider).save(draft);
    });
    if (!mounted) return;
    switch (result?.status) {
      case PolicySaveStatus.saved || PolicySaveStatus.replayed:
        AppSnack.success(context, l10n?.assistantSetupSaved ?? 'Saved.');
      case PolicySaveStatus.stale || PolicySaveStatus.conflict:
        AppSnack.error(
          context,
          l10n?.assistantSetupStale ??
              'Someone changed the offer meanwhile. Review it and try again.',
        );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = ref.watch(currentMcpContextProvider);
    final unavailable = InlineBanner(
      key: const ValueKey('assistant-setup-unavailable'),
      icon: Icons.cloud_off_outlined,
      severity: InlineBannerSeverity.error,
      text:
          l10n?.mcpNextUnavailable ??
          'The server could not answer. Nothing is assumed; try again later.',
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.assistantSetupTitle ?? 'Assistant setup'),
      ),
      body: scope.when(
        loading: () => const LoadingView(),
        error: (_, _) => _padded(unavailable),
        data: (captured) => captured == null
            ? _padded(
                Text(
                  key: const ValueKey('assistant-setup-no-workspace'),
                  l10n?.assistantSetupNoWorkspace ??
                      'Select a workspace first.',
                ),
              )
            : ref
                  .watch(assistantSetupProvider(captured))
                  .when(
                    loading: () => const LoadingView(),
                    error: (_, _) => _padded(unavailable),
                    data: (setup) => _checklist(l10n, captured, setup),
                  ),
      ),
    );
  }

  Widget _padded(Widget child) =>
      Padding(padding: const EdgeInsets.all(AppSpacing.md), child: child);

  Widget _checklist(
    AppLocalizations? l10n,
    McpContextRef scope,
    AssistantSetup setup,
  ) {
    final next = setup.next;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          l10n?.assistantSetupIntro ??
              'What assistants need to work in this workspace, in order. '
                  'Each step says who takes it.',
        ),
        const SizedBox(height: AppSpacing.sm),
        InlineBanner(
          key: ValueKey('assistant-setup-next-${next?.step.name ?? 'none'}'),
          icon: next == null ? Icons.check_circle_outline : Icons.flag_outlined,
          severity: next?.state == AssistantSetupState.unavailable
              ? InlineBannerSeverity.error
              : InlineBannerSeverity.info,
          text: next == null
              ? (l10n?.assistantSetupAllDone ??
                    'Everything is set up for this workspace.')
              : assistantSetupNextText(l10n, next),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in setup.items)
          _StepCard(
            item: item,
            actions: _actions(l10n, scope, item),
            extra: switch (item.step) {
              AssistantSetupStep.connect => const _ConnectorInstructions(),
              AssistantSetupStep.installation => const _InstanceContact(),
              _ => null,
            },
          ),
      ],
    );
  }

  List<Widget> _actions(
    AppLocalizations? l10n,
    McpContextRef scope,
    AssistantSetupItem item,
  ) {
    Widget button(String key, String label, VoidCallback onPressed) =>
        TextButton(
          key: ValueKey('assistant-setup-$key'),
          onPressed: _busy ? null : onPressed,
          child: Text(label),
        );
    final admin =
        ref
            .watch(myDatabaseCapabilitiesProvider)
            .value
            ?.databaseAdministrator ??
        false;
    return switch (item.step) {
      AssistantSetupStep.identity when item.canAct => [
        button(
          'link-identity',
          l10n?.assistantSetupLinkIdentity ?? 'Confirm my identity',
          () => confirmAssistantIdentity(context, ref),
        ),
      ],
      AssistantSetupStep.workspace when item.canAct => [
        button(
          'turn-on',
          l10n?.assistantSetupTurnOn ?? 'Turn on',
          () => _turnOn(scope),
        ),
      ],
      AssistantSetupStep.policy when item.canAct => [
        button(
          'recommended',
          l10n?.assistantSetupRecommended ?? 'Use the recommended set',
          () => _recommend(scope),
        ),
        button(
          'customise',
          l10n?.assistantSetupCustomise ?? 'Customise',
          () => context.push('/settings/assistants'),
        ),
      ],
      AssistantSetupStep.eligibility => [
        if (item.canAct)
          button(
            'request',
            l10n?.assistantSetupRequest ?? 'Ask for access',
            () => _run(
              scope,
              'assistant setup eligibility request failed',
              () => ref.read(assistantAccessProvider).requestEligibility(),
            ),
          ),
        // A database administrator decides OTHER people's requests; the
        // server refuses anyone deciding their own.
        if (admin)
          button(
            'review',
            l10n?.assistantSetupReview ?? 'Review requests',
            () => context.push('/database/assistant-approvals'),
          ),
      ],
      _ => const [],
    };
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.item, required this.actions, this.extra});

  final AssistantSetupItem item;
  final List<Widget> actions;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final done = item.state == AssistantSetupState.done;
    return Card(
      key: ValueKey('assistant-setup-${item.step.name}-${item.state.name}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  assistantSetupStateIcon(item.state),
                  color: done ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    assistantSetupStepTitle(l10n, item.step),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(assistantSetupStepReason(l10n, item.step)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${assistantSetupStateLabel(l10n, item.state)} · '
              '${assistantSetupActorLabel(l10n, item.actor)}',
              style: theme.textTheme.bodySmall,
            ),
            if (extra != null && !done) ...[
              const SizedBox(height: AppSpacing.sm),
              extra!,
            ],
            if (actions.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                children: actions,
              ),
          ],
        ),
      ),
    );
  }
}

/// The connector URL to copy and the three steps in the assistant.
class _ConnectorInstructions extends ConsumerWidget {
  const _ConnectorInstructions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final url = ref.watch(mcpConnectorUrlProvider);
    if (url == null) {
      return Text(
        key: const ValueKey('assistant-setup-no-connector'),
        l10n?.assistantSetupNoConnector ??
            'This app runs without a server, so there is no connector URL.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          key: const ValueKey('assistant-setup-connector-url'),
          '$url',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('assistant-setup-copy-url'),
            icon: const Icon(Icons.copy_outlined),
            label: Text(l10n?.assistantSetupCopyUrl ?? 'Copy connector URL'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '$url'));
              if (context.mounted) {
                AppSnack.success(
                  context,
                  l10n?.assistantSetupCopied ?? 'Connector URL copied.',
                );
              }
            },
          ),
        ),
        Text(
          l10n?.assistantSetupConnectHowTo ??
              '1. In your assistant, add a custom connector with this URL.\n'
                  '2. Sign in with your DesKilo account when asked.\n'
                  '3. Approve this workspace and the operations you allow.',
        ),
        // #2145 — the steps per assistant, one-click links and a test.
        if (ref
            .watch(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.mcpAccess))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('assistant-setup-open-guide'),
              onPressed: () => context.push(connectAssistantRoute),
              child: Text(
                l10n?.mcpConnectOpenGuide ?? 'Open the connection guide',
              ),
            ),
          ),
      ],
    );
  }
}

/// #1829 — who answers for this installation, by name only: the
/// installation step waits on them. Their addresses stay on the Instance
/// card; nothing private is shown to explain a blocker.
class _InstanceContact extends ConsumerWidget {
  const _InstanceContact();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final who = ref.watch(instanceResponsiblesProvider).value;
    if (who == null) return const SizedBox.shrink();
    if (who.isOperator) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            key: const ValueKey('assistant-setup-instance-you'),
            l10n?.assistantSetupInstanceYou ??
                'You answer for this database: switch assistants on from the '
                    'instance tools.',
          ),
          // #2145 — the place where that is done, one tap away.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('assistant-setup-open-installation'),
              onPressed: () => context.push('/installation/assistants'),
              child: Text(
                l10n?.mcpConnectOpenInstallation ??
                    'Open the installation console',
              ),
            ),
          ),
        ],
      );
    }
    final names = [
      for (final p in [...who.owners, ...who.delegates])
        if (p.name.isNotEmpty) p.name,
    ];
    if (names.isEmpty) {
      return Text(
        key: const ValueKey('assistant-setup-instance-nobody'),
        l10n?.assistantSetupInstanceNobody ??
            'Nobody answers for this database yet.',
      );
    }
    return Text(
      key: const ValueKey('assistant-setup-instance-names'),
      l10n?.assistantSetupInstanceNames(names.join(', ')) ??
          'Answering for this database: ${names.join(', ')}.',
    );
  }
}

/// What "Use the recommended set" would change, before anything is sent.
class _PreviewDialog extends StatelessWidget {
  const _PreviewDialog({
    required this.added,
    required this.removed,
    required this.narrows,
    required this.unchanged,
  });

  final Set<String> added;
  final Set<String> removed;
  final bool narrows;
  final bool unchanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    List<Widget> section(String key, String title, Set<String> ops) => [
      if (ops.isNotEmpty) ...[
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        for (final op in ops.toList()..sort())
          Text(
            key: ValueKey('assistant-setup-preview-$key-$op'),
            '• ${mcpOperationLabel(l10n, op)}',
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
    return AlertDialog(
      key: const ValueKey('assistant-setup-preview'),
      title: Text(l10n?.assistantSetupPreviewTitle ?? 'Recommended set'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unchanged)
              Text(
                key: const ValueKey('assistant-setup-preview-unchanged'),
                l10n?.assistantSetupPreviewNone ??
                    'No change: the workspace already offers exactly this set.',
              )
            else ...[
              ...section(
                'add',
                l10n?.assistantSetupPreviewAdds ?? 'Added',
                added,
              ),
              ...section(
                'remove',
                l10n?.assistantSetupPreviewRemoves ?? 'Removed',
                removed,
              ),
              if (narrows)
                Text(
                  key: const ValueKey('assistant-setup-preview-own'),
                  l10n?.assistantSetupPreviewOwn ??
                      'Assistants see only each member\'s own records.',
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n?.assistantSetupPreviewNote ??
                    'Only a member\'s own records and the availability reads. '
                        'Assistants already connected get new operations only '
                        'after each person approves again.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('assistant-setup-preview-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        if (!unchanged)
          FilledButton(
            key: const ValueKey('assistant-setup-preview-apply'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.assistantSetupApply ?? 'Apply'),
          ),
      ],
    );
  }
}
