// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/mcp_access_status.dart';
import '../../providers/mcp_providers.dart';
import '../confirm_identity.dart';

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
    final l10n = context.l10n;
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
            l10n.mcpOverviewTitle,
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
    final l10n = context.l10n;
    final s = status;
    final next = s.next;
    final rows = <(String, String, Enum)>[
      ('google', l10n.mcpStatusGoogle, s.google),
      ('identity', l10n.mcpStatusIdentity, s.identity),
      (
        'eligibility',
        l10n.mcpStatusEligibility,
        s.eligibility,
      ),
      ('exposure', l10n.mcpStatusExposure, s.exposure),
      ('role', l10n.mcpStatusRole, s.role),
      ('consent', l10n.mcpStatusConsent, s.consent),
      ('backend', l10n.mcpStatusBackend, s.backend),
    ];
    return Card(
      key: const ValueKey('mcp-status'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.mcpStatusTitle,
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
                    ? (l10n.mcpStateAfterPrevious)
                    : _mcpStateLabel(l10n, state)),
              ),
            _Banner(
              'mcp-status-next-${next.name}',
              _nextText(l10n, next),
              next == McpNextStep.unavailable || next == McpNextStep.roleDenied
                  ? InlineBannerSeverity.error
                  : InlineBannerSeverity.info,
            ),
            if (next == McpNextStep.linkGoogle)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('mcp-status-link-google'),
                  // Here the sign-in methods page IS the place: it links
                  // Google to this account.
                  onPressed: () => context.push('/linked-accounts'),
                  child: Text(l10n.mcpStatusLinkGoogle),
                ),
              ),
            if (next == McpNextStep.signInWithGoogle)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('mcp-status-sign-in-google'),
                  onPressed: () => runGuarded(
                    context,
                    domain: 'mcp',
                    message: 'google sign-in failed',
                    action: () =>
                        ref.read(assistantAccessProvider).signInWithGoogle(),
                  ),
                  child: Text(
                    l10n.mcpStatusSignInGoogle,
                  ),
                ),
              ),
            if (next == McpNextStep.linkIdentity)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('mcp-status-link-identity'),
                  // Taken here: the sign-in methods page cannot take it.
                  onPressed: () => confirmAssistantIdentity(context, ref),
                  child: Text(
                    l10n.mcpStatusConfirmIdentity,
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
    final l10n = context.l10n;
    final s = status;
    final host = Uri.tryParse(s.source)?.host ?? s.source;
    final reachable = s.backend != McpBackendState.unavailable;
    final detail = reachable
        ? '${l10n.mcpStatusIdentity}: '
              '${_mcpStateLabel(l10n, s.identity)} · '
              '${l10n.mcpStatusEligibility}: '
              '${_mcpStateLabel(l10n, s.eligibility)}'
        : (l10n.mcpOverviewUnavailable);
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

String _nextText(AppLocalizations l10n, McpNextStep step) => switch (step) {
  McpNextStep.linkGoogle =>
    l10n.mcpNextLinkGoogle,
  McpNextStep.signInWithGoogle =>
    l10n.mcpNextSignInGoogle,
  McpNextStep.linkIdentity =>
    l10n.mcpNextLinkIdentity,
  McpNextStep.requestEligibility =>
    l10n.mcpNextRequestEligibility,
  McpNextStep.awaitEligibility =>
    l10n.mcpNextAwaitEligibility,
  McpNextStep.ownerExposes =>
    l10n.mcpNextOwnerExposes,
  McpNextStep.roleDenied =>
    l10n.mcpNextRoleDenied,
  McpNextStep.consent =>
    l10n.mcpNextConsent,
  McpNextStep.ready =>
    l10n.mcpNextReady,
  McpNextStep.unavailable =>
    l10n.mcpNextUnavailable,
};

/// One label per state value, whichever dimension it belongs to.
String _mcpStateLabel(AppLocalizations l10n, Enum state) =>
    switch (state.name) {
      'verified' => l10n.mcpStateVerified,
      'unlinked' => l10n.mcpStateUnlinked,
      'notRequested' => l10n.mcpStateNotRequested,
      'pending' => l10n.mcpStatePending,
      'approved' => l10n.mcpStateApproved,
      'revoked' => l10n.mcpStateRevoked,
      'disabled' => l10n.mcpStateDisabled,
      'exposed' => l10n.mcpStateExposed,
      'allowed' => l10n.mcpStateAllowed,
      'denied' => l10n.mcpStateDenied,
      'missing' => l10n.mcpStateMissing,
      'current' => l10n.mcpStateCurrent,
      'available' => l10n.mcpStateAvailable,
      'incompatible' => l10n.mcpStateIncompatible,
      'ready' => l10n.mcpStateGoogleReady,
      'signInWithGoogle' =>
        l10n.mcpStateGoogleOtherSession,
      'linkGoogle' => l10n.mcpStateGoogleMissing,
      _ => l10n.mcpStateUnavailable,
    };
