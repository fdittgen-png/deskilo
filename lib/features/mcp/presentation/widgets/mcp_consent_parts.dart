// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../auth/domain/identity_binding.dart';
import '../../../workspace/providers/instance_providers.dart';
import '../../domain/mcp_access_status.dart';
import '../../domain/mcp_onboarding.dart';
import '../../providers/mcp_providers.dart';
import '../mcp_consent_refusal.dart';

/// A banner with the consent page's spacing.
class ConsentBanner extends StatelessWidget {
  const ConsentBanner(
    this.keyName,
    this.text,
    this.icon,
    this.severity, {
    super.key,
  });

  final String keyName;
  final String text;
  final IconData icon;
  final InlineBannerSeverity severity;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: InlineBanner(
      key: ValueKey(keyName),
      icon: icon,
      severity: severity,
      text: text,
    ),
  );
}

/// 0340 — consent needs a Google sign-in; read once per visit.
class ConsentGoogleGate extends ConsumerStatefulWidget {
  const ConsentGoogleGate({super.key});

  @override
  ConsumerState<ConsentGoogleGate> createState() => _ConsentGoogleGateState();
}

class _ConsentGoogleGateState extends ConsumerState<ConsentGoogleGate> {
  late final Future<McpGoogleSignIn> _google = ref
      .read(assistantAccessProvider)
      .googleSignIn();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<McpGoogleSignIn>(
      future: _google,
      builder: (context, snap) {
        final state = mcpGoogleState(snap.data);
        if (!snap.hasData || state == McpGoogleState.ready) {
          return const SizedBox.shrink();
        }
        final link = state == McpGoogleState.linkGoogle;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConsentBanner(
                'mcp-consent-google-${state.name}',
                link ? (l10n.mcpNextLinkGoogle) : (l10n.mcpNextSignInGoogle),
                Icons.lock_outline,
                InlineBannerSeverity.error,
              ),
              if (!link)
                OutlinedButton(
                  key: const ValueKey('mcp-consent-sign-in-google'),
                  onPressed: () => runGuarded(
                    context,
                    domain: 'mcp',
                    message: 'google sign-in failed',
                    action: () =>
                        ref.read(assistantAccessProvider).signInWithGoogle(),
                  ),
                  child: Text(l10n.mcpStatusSignInGoogle),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Where the answer goes, and the family an approval covers.
class ConsentClientFacts extends StatelessWidget {
  const ConsentClientFacts(this.client, {super.key});

  final ConsentClient client;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final host = client.redirectHost;
    final family = switch (client.family) {
      'claude' => l10n.mcpConsentFamilyClaude,
      'chatgpt' => l10n.mcpConsentFamilyChatgpt,
      'loopback' => l10n.mcpConsentFamilyLoopback,
      _ => null,
    };
    final approved = client.status == McpClientApproval.approved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (host != null && host.isNotEmpty)
          Text(
            key: const ValueKey('mcp-consent-redirect-host'),
            l10n.mcpConsentRedirectHost(host),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (approved && family != null)
          Text(
            key: ValueKey('mcp-consent-family-${client.family}'),
            family,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

/// Who takes the open step: you (with the console), a named person, or
/// nobody yet.
class ConsentDeciderLine extends StatelessWidget {
  const ConsentDeciderLine(this.d, {super.key});

  final ConsentDecider d;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (d.me) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            key: const ValueKey('mcp-consent-decider-me'),
            l10n.mcpConsentDeciderMe,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('mcp-consent-open-console'),
              onPressed: () => context.push('/installation/assistants'),
              child: Text(l10n.mcpConnectOpenInstallation),
            ),
          ),
        ],
      );
    }
    final name = d.displayName;
    return Text(
      key: ValueKey('mcp-consent-decider-${d.kind.name}'),
      name == null || name.isEmpty
          ? (l10n.mcpConsentDeciderNobody)
          : (l10n.mcpConsentDeciderAsk(name)),
    );
  }
}

/// A refusal the server explained, with who can lift it when that is the
/// installation's operator.
class ConsentRefusalBanner extends ConsumerWidget {
  const ConsentRefusalBanner(this.r, {super.key});

  final McpConsentRefusal r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    var text = mcpConsentRefusalText(l10n, r);
    if (r == McpConsentRefusal.clientNotApproved) {
      final who = ref.watch(instanceResponsiblesProvider).value;
      final names = [
        for (final p in [...?who?.owners, ...?who?.delegates])
          if (p.name.isNotEmpty) p.name,
      ];
      if (names.isNotEmpty) {
        text = '$text ${l10n.mcpConnectWaitingOperator(names.join(', '))}';
      }
    }
    return ConsentBanner(
      'mcp-consent-refused-${r.name}',
      text,
      Icons.lock_outline,
      InlineBannerSeverity.error,
    );
  }
}

/// The banner for how the last request ended.
class ConsentOutcomeBanner extends StatelessWidget {
  const ConsentOutcomeBanner(this.outcome, {super.key});

  final String outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (outcome) {
      'connected' => ConsentBanner(
        'mcp-consent-connected',
        l10n.mcpConsentConnected,
        Icons.check_circle_outline,
        InlineBannerSeverity.info,
      ),
      'denied' => ConsentBanner(
        'mcp-consent-denied',
        l10n.mcpConsentDenied,
        Icons.block,
        InlineBannerSeverity.info,
      ),
      'approvedNotFinalized' => ConsentBanner(
        'mcp-consent-partial',
        l10n.mcpConsentPartial,
        Icons.sync_problem_outlined,
        InlineBannerSeverity.error,
      ),
      'eligibilityRequested' => ConsentBanner(
        'mcp-consent-requested',
        l10n.mcpConsentRequested,
        Icons.hourglass_top,
        InlineBannerSeverity.info,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// #2145 — an assistant the operator has not approved: the cause, who
/// decides, and Deny. Nothing is asked of Auth but the refusal.
class ConsentNotApproved extends StatelessWidget {
  const ConsentNotApproved({
    super.key,
    required this.client,
    required this.decider,
    required this.outcome,
    required this.onDeny,
  });

  final ConsentClient client;
  final ConsentDecider? decider;
  final String? outcome;

  /// Null while a request runs or the browser already left.
  final VoidCallback? onDeny;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = client.name.isEmpty ? client.clientId : client.name;
    final blocked = client.status == McpClientApproval.blocked;
    final decider = this.decider;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mcpConsentTitle)),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          if (outcome case final o?) ConsentOutcomeBanner(o),
          ConsentBanner(
            'mcp-consent-client-${client.status.name}',
            blocked
                ? l10n.mcpConsentClientBlocked(name)
                : l10n.mcpConsentClientWaiting(name),
            Icons.lock_outline,
            InlineBannerSeverity.error,
          ),
          ConsentClientFacts(client),
          if (!blocked && decider != null) ConsentDeciderLine(decider),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            key: const ValueKey('mcp-consent-deny'),
            onPressed: onDeny,
            child: Text(l10n.mcpConsentDeny),
          ),
        ],
      ),
    );
  }
}
