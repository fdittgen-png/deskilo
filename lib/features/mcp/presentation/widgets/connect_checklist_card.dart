// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/instance_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/connect_checklist.dart';
import '../../domain/mcp_context.dart';
import '../../providers/mcp_providers.dart';
import '../confirm_identity.dart';
import 'connect_workspaces.dart';

/// What stands between this person and a first assistant call, one row
/// per [ConnectChecklist] item; [run] performs a guarded action and
/// [busy] disables the buttons meanwhile.
class ConnectChecklistCard extends ConsumerWidget {
  const ConnectChecklistCard({
    super.key,
    required this.scope,
    required this.busy,
    required this.run,
  });

  final McpContextRef scope;
  final bool busy;
  final Future<void> Function(String message, Future<void> Function() action)
  run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(mcpAccessStatusProvider(scope));
    final caps = ref.watch(myDatabaseCapabilitiesProvider);
    final who = ref.watch(instanceResponsiblesProvider).value;
    final manages = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.manageIntegrations);
    final now = ref.watch(clockProvider).now();
    return status.when(
      loading: () => const LoadingView(),
      error: (_, _) => const ConnectUnavailable(),
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
                  _ConnectRow(
                    item: item,
                    operators: operators,
                    expiresSoon: list.accessExpiresSoon,
                    busy: busy,
                    run: run,
                  ),
                if (list.phase == ConnectPhase.ready)
                  InlineBanner(
                    key: const ValueKey('mcp-connect-all-done'),
                    icon: Icons.check_circle_outline,
                    severity: InlineBannerSeverity.info,
                    text: l10n.mcpConnectAllDone,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConnectRow extends ConsumerWidget {
  const _ConnectRow({
    required this.item,
    required this.operators,
    required this.expiresSoon,
    required this.busy,
    required this.run,
  });

  final ConnectItem item;
  final List<String> operators;
  final bool expiresSoon;
  final bool busy;
  final Future<void> Function(String message, Future<void> Function() action)
  run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
    final action = _action(context, ref, l10n);
    return Column(
      key: ValueKey('mcp-connect-step-${item.step.name}-${item.state.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: color),
          title: Text(_connectStepTitle(l10n, item.step)),
          subtitle: Text(
            _connectStepDetail(
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

  Widget? _action(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    Widget button(String label, VoidCallback onPressed) => TextButton(
      key: ValueKey('mcp-connect-action-${item.step.name}-${item.action.name}'),
      onPressed: busy ? null : onPressed,
      child: Text(label),
    );
    final access = ref.read(assistantAccessProvider);
    return switch (item.action) {
      ConnectAction.none || ConnectAction.addConnector => null,
      ConnectAction.linkGoogle => button(
        l10n.mcpStatusLinkGoogle,
        () => context.push('/linked-accounts'),
      ),
      ConnectAction.signInWithGoogle => button(
        l10n.mcpStatusSignInGoogle,
        () => run('google sign-in failed', access.signInWithGoogle),
      ),
      ConnectAction.confirmIdentity => button(
        l10n.mcpStatusConfirmIdentity,
        () => confirmAssistantIdentity(context, ref),
      ),
      ConnectAction.requestAccess => button(
        l10n.mcpConsentRequestEligibility,
        () => run('eligibility request failed', access.requestEligibility),
      ),
      ConnectAction.openSetup => button(
        l10n.mcpConnectOpenSetup,
        () => context.push('/settings/assistant-setup'),
      ),
      ConnectAction.openInstallation => button(
        l10n.mcpConnectOpenInstallation,
        () => context.push('/installation/assistants'),
      ),
      // No conversation reaches the operator from a workspace (their
      // account id is not shown to members), so the request is copied
      // for whichever channel the person uses to reach them.
      ConnectAction.askOperator => button(l10n.mcpConnectCopyRequest, () async {
        await Clipboard.setData(
          ClipboardData(text: l10n.mcpConnectOperatorRequest),
        );
        if (context.mounted) {
          AppSnack.success(context, l10n.mcpConnectCopied);
        }
      }),
    };
  }
}

String _connectStepTitle(AppLocalizations l10n, ConnectStep step) =>
    switch (step) {
      ConnectStep.google => l10n.mcpConnectStepGoogle,
      ConnectStep.identity => l10n.mcpConnectStepIdentity,
      ConnectStep.access => l10n.mcpConnectStepAccess,
      ConnectStep.workspace => l10n.mcpConnectStepWorkspace,
      ConnectStep.server => l10n.mcpConnectStepServer,
      ConnectStep.connect => l10n.mcpConnectStepConnect,
    };

/// The state of [item] in words, and who acts when it is someone else.
String _connectStepDetail(
  AppLocalizations l10n,
  ConnectItem item, {
  List<String> operators = const [],
  bool expiresSoon = false,
}) {
  final days = item.expiresInDays;
  if (item.state == ConnectState.done) {
    if (item.step == ConnectStep.access && days != null) {
      return expiresSoon
          ? (l10n.mcpConnectAccessExpiresSoon(days))
          : (l10n.mcpConnectAccessExpiresIn(days));
    }
    return l10n.mcpConnectDone;
  }
  if (item.roleDenied) {
    return l10n.mcpConnectRoleDenied;
  }
  return switch (item.state) {
    ConnectState.todo => switch (item.step) {
      ConnectStep.connect => l10n.mcpConnectTodoConnect,
      _ => l10n.mcpConnectTodoYou,
    },
    ConnectState.waiting => switch (item.actor) {
      ConnectActor.workspaceAdmin => l10n.mcpConnectWaitingWorkspaceAdmin,
      ConnectActor.databaseAdministrator => l10n.mcpConnectWaitingDatabaseAdmin,
      ConnectActor.operator =>
        operators.isEmpty
            ? (l10n.mcpConnectWaitingOperatorUnknown)
            : (l10n.mcpConnectWaitingOperator(operators.join(', '))),
      ConnectActor.you => l10n.mcpConnectTodoYou,
    },
    ConnectState.blocked => l10n.mcpStateAfterPrevious,
    ConnectState.unavailable => l10n.mcpConnectUnavailable,
    ConnectState.done => l10n.mcpConnectDone,
  };
}
