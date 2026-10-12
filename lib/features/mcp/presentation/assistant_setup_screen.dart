// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/assistant_setup.dart';
import '../application/mcp_onboarding_commands.dart';
import '../application/mcp_policy_editor.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_context.dart';
import '../providers/assistant_setup_providers.dart';
import '../providers/mcp_providers.dart';
import 'assistant_setup_labels.dart';
import 'confirm_identity.dart';
import 'widgets/assistant_setup_parts.dart';

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
            context.l10n.assistantSetupStale,
          );
        }
        ref.invalidate(myWorkspacesProvider);
      });

  /// Shows exactly what the recommended set changes, and saves it only
  /// when the person applies it.
  Future<void> _recommend(McpContextRef scope) async {
    final l10n = context.l10n;
    final McpPolicy policy;
    try {
      policy = await ref.read(mcpPolicyProvider(scope).future);
    } on Object catch (e, st) {
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
      builder: (context) => AssistantPreviewDialog(
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
        AppSnack.success(context, l10n.assistantSetupSaved);
      case PolicySaveStatus.stale || PolicySaveStatus.conflict:
        AppSnack.error(
          context,
          l10n.assistantSetupStale,
        );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scope = ref.watch(currentMcpContextProvider);
    final unavailable = InlineBanner(
      key: const ValueKey('assistant-setup-unavailable'),
      icon: Icons.cloud_off_outlined,
      text:
          l10n.mcpNextUnavailable,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assistantSetupTitle),
      ),
      body: scope.when(
        loading: () => const LoadingView(),
        error: (_, _) => _padded(unavailable),
        data: (captured) => captured == null
            ? _padded(
                Text(
                  key: const ValueKey('assistant-setup-no-workspace'),
                  l10n.assistantSetupNoWorkspace,
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
    AppLocalizations l10n,
    McpContextRef scope,
    AssistantSetup setup,
  ) {
    final next = setup.next;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          l10n.assistantSetupIntro,
        ),
        const SizedBox(height: AppSpacing.sm),
        InlineBanner(
          key: ValueKey('assistant-setup-next-${next?.step.name ?? 'none'}'),
          icon: next == null ? Icons.check_circle_outline : Icons.flag_outlined,
          severity: next?.state == AssistantSetupState.unavailable
              ? InlineBannerSeverity.error
              : InlineBannerSeverity.info,
          text: next == null
              ? (l10n.assistantSetupAllDone)
              : assistantSetupNextText(l10n, next),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in setup.items)
          AssistantSetupStepCard(
            item: item,
            actions: _actions(l10n, scope, item),
            extra: switch (item.step) {
              AssistantSetupStep.connect => const AssistantConnectorInstructions(),
              AssistantSetupStep.installation => const AssistantInstanceContact(),
              _ => null,
            },
          ),
      ],
    );
  }

  List<Widget> _actions(
    AppLocalizations l10n,
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
          l10n.assistantSetupLinkIdentity,
          () => confirmAssistantIdentity(context, ref),
        ),
      ],
      AssistantSetupStep.workspace when item.canAct => [
        button(
          'turn-on',
          l10n.assistantSetupTurnOn,
          () => _turnOn(scope),
        ),
      ],
      AssistantSetupStep.policy when item.canAct => [
        button(
          'recommended',
          l10n.assistantSetupRecommended,
          () => _recommend(scope),
        ),
        button(
          'customise',
          l10n.assistantSetupCustomise,
          () => context.push('/settings/assistants'),
        ),
      ],
      AssistantSetupStep.eligibility => [
        if (item.canAct)
          button(
            'request',
            l10n.assistantSetupRequest,
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
            l10n.assistantSetupReview,
            () => context.push('/database/assistant-approvals'),
          ),
      ],
      _ => const [],
    };
  }
}
