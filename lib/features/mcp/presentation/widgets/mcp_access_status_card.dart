// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../confirm_identity.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/mcp_access_status.dart';
import '../../providers/mcp_providers.dart';

/// #1625 — where the person stands with assistants on the selected
/// workspace, as the six facts the server answers (identity, database
/// approval, the owner's offer, role, consent, server) and the one next
/// step with who takes it. Below, read-only, the other installations the
/// account connected, each asked through its own client: one failing
/// reads "could not be asked" and hides none of the others. Nothing here
/// enables an action; the facts only explain.
class McpAccessStatusCard extends ConsumerWidget {
  const McpAccessStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scope = ref.watch(currentMcpContextProvider);
    final overview = ref.watch(connectedMcpOverviewProvider).value ?? const [];
    final unavailable = _Banner(
      'mcp-status-next-unavailable',
      _nextText(l10n, McpNextStep.unavailable),
      InlineBannerSeverity.error,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...scope.when(
          loading: () => const [LoadingView()],
          error: (_, _) => [unavailable],
          data: (captured) => captured == null
              ? const <Widget>[]
              : [
                  ref
                      .watch(mcpAccessStatusProvider(captured))
                      .when(
                        loading: () => const LoadingView(),
                        error: (_, _) => unavailable,
                        data: (s) => _StatusCard(status: s),
                      ),
                ],
        ),
        if (overview.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            key: const ValueKey('mcp-overview-title'),
            l10n?.mcpOverviewTitle ?? 'Other connected databases',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final o in overview) _OverviewTile(status: o),
        ],
      ],
    );
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.status});
  final McpAccessStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = status;
    final next = s.next;
    final rows = <(String, String, Enum)>[
      ('identity', l10n?.mcpStatusIdentity ?? 'Identity', s.identity),
      (
        'eligibility',
        l10n?.mcpStatusEligibility ?? 'Database approval',
        s.eligibility,
      ),
      ('exposure', l10n?.mcpStatusExposure ?? 'Workspace offer', s.exposure),
      ('role', l10n?.mcpStatusRole ?? 'Your role', s.role),
      ('consent', l10n?.mcpStatusConsent ?? 'Your consent', s.consent),
      ('backend', l10n?.mcpStatusBackend ?? 'Server', s.backend),
    ];
    return Card(
      key: const ValueKey('mcp-status'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.mcpStatusTitle ?? 'Where you stand here',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final (key, label, state) in rows)
              ListTile(
                key: ValueKey('mcp-status-$key-${state.name}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                // A fact that waits on an earlier unmet step is not
                // "unknown": it is decided after that step.
                trailing: Text(state.name == 'unavailable' &&
                        next != McpNextStep.unavailable
                    ? (l10n?.mcpStateAfterPrevious ?? 'After the step above')
                    : mcpStateLabel(l10n, state)),
              ),
            _Banner(
              'mcp-status-next-${next.name}',
              _nextText(l10n, next),
              next == McpNextStep.unavailable || next == McpNextStep.roleDenied
                  ? InlineBannerSeverity.error
                  : InlineBannerSeverity.info,
            ),
            if (next == McpNextStep.linkIdentity)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('mcp-status-link-identity'),
                  // Taken here: the sign-in methods page cannot take it.
                  onPressed: () => confirmAssistantIdentity(context, ref),
                  child: Text(
                    l10n?.mcpStatusConfirmIdentity ?? 'Confirm my identity',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({required this.status});
  final McpInstanceStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = status;
    final host = Uri.tryParse(s.source)?.host ?? s.source;
    final reachable = s.backend != McpBackendState.unavailable;
    final detail = reachable
        ? '${l10n?.mcpStatusIdentity ?? 'Identity'}: '
              '${mcpStateLabel(l10n, s.identity)} · '
              '${l10n?.mcpStatusEligibility ?? 'Database approval'}: '
              '${mcpStateLabel(l10n, s.eligibility)}'
        : (l10n?.mcpOverviewUnavailable ?? 'Could not be asked right now.');
    return ListTile(
      key: ValueKey(
        'mcp-overview-$host-${reachable ? s.eligibility.name : 'unavailable'}',
      ),
      contentPadding: EdgeInsets.zero,
      leading: Icon(reachable ? Icons.dns_outlined : Icons.cloud_off_outlined),
      title: Text(host),
      subtitle: Text(detail),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.id, this.text, this.severity);
  final String id;
  final String text;
  final InlineBannerSeverity severity;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: InlineBanner(
      key: ValueKey(id),
      icon: Icons.flag_outlined,
      severity: severity,
      text: text,
    ),
  );
}

String _nextText(AppLocalizations? l10n, McpNextStep step) => switch (step) {
  McpNextStep.linkIdentity =>
    l10n?.mcpNextLinkIdentity ??
        'Next: you link your account to this database\'s identity.',
  McpNextStep.requestEligibility =>
    l10n?.mcpNextRequestEligibility ??
        'Next: you ask this database\'s administrators for approval.',
  McpNextStep.awaitEligibility =>
    l10n?.mcpNextAwaitEligibility ??
        'Next: a database administrator decides your request.',
  McpNextStep.ownerExposes =>
    l10n?.mcpNextOwnerExposes ??
        'Next: the workspace owner offers operations to assistants.',
  McpNextStep.roleDenied =>
    l10n?.mcpNextRoleDenied ??
        'Your role leaves no operation to offer here. The workspace owner '
            'decides what each role may do.',
  McpNextStep.consent =>
    l10n?.mcpNextConsent ??
        'Next: connect an assistant from the assistant itself and approve '
            'this workspace.',
  McpNextStep.ready =>
    l10n?.mcpNextReady ??
        'Ready: a connected assistant may act for you in this workspace, '
            'within what you approved.',
  McpNextStep.unavailable =>
    l10n?.mcpNextUnavailable ??
        'The server could not answer. Nothing is assumed; try again later.',
};

/// One label per state value, whichever dimension it belongs to.
String mcpStateLabel(AppLocalizations? l10n, Enum state) =>
    switch (state.name) {
      'verified' => l10n?.mcpStateVerified ?? 'Verified',
      'unlinked' => l10n?.mcpStateUnlinked ?? 'Not linked',
      'notRequested' => l10n?.mcpStateNotRequested ?? 'Not requested',
      'pending' => l10n?.mcpStatePending ?? 'Waiting for a decision',
      'approved' => l10n?.mcpStateApproved ?? 'Approved',
      'revoked' => l10n?.mcpStateRevoked ?? 'Expired or withdrawn',
      'disabled' => l10n?.mcpStateDisabled ?? 'Nothing offered',
      'exposed' => l10n?.mcpStateExposed ?? 'Operations offered',
      'allowed' => l10n?.mcpStateAllowed ?? 'Allowed',
      'denied' => l10n?.mcpStateDenied ?? 'Nothing for your role',
      'missing' => l10n?.mcpStateMissing ?? 'Not given',
      'current' => l10n?.mcpStateCurrent ?? 'Given',
      'available' => l10n?.mcpStateAvailable ?? 'Reachable',
      'incompatible' => l10n?.mcpStateIncompatible ?? 'Incompatible version',
      _ => l10n?.mcpStateUnavailable ?? 'Unknown',
    };
