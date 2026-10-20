// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/presentation/welcome_link_button.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../application/federation_handoff_controller.dart';
import '../../domain/social_provider.dart';
import '../../providers/auth_providers.dart';
import 'federation_handoff_panel.dart';

/// "Or continue with" and what follows (0051): browser-based Supabase OAuth
/// buttons -- no vendor SDKs, the session lands via the deskilo:// callback
/// and a provider the server has not enabled surfaces as a snack -- and, when
/// the federation handoff applies, the explicit Continue with Deskilo
/// (#1648).
class AuthSocialSection extends ConsumerWidget {
  const AuthSocialSection({
    super.key,
    required this.busy,
    required this.onProvider,
    required this.onUseExistingAccount,
  });

  final bool busy;
  final ValueChanged<SocialProvider> onProvider;
  final VoidCallback onUseExistingAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final handoff = ref.watch(federationHandoffAvailableProvider);
    final offersDeskilo =
        (ref.watch(availableSocialProvidersProvider).value ??
                const <SocialProvider>[])
            .contains(SocialProvider.deskilo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Social sign-in (0051): browser-based Supabase OAuth —
        // no vendor SDKs. The session lands via
        // the deskilo:// callback; errors (provider not enabled
        // on the server) surface as a snack.
        Row(
          children: [
            const Expanded(child: Divider()),
            // #1205 — Flexible, not a bare Padding: at a large
            // text scale "or continue with" is wider than the
            // rules leave it, and a fixed child in a Row answers
            // that by overflowing off the right of a phone.
            // Flexible lets the sentence wrap to two lines
            // instead, which is what the rest of this form does.
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  l10n.authContinueWith,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final provider
                in ref.watch(availableSocialProvidersProvider).value ??
                    const <SocialProvider>[])
              if (provider != SocialProvider.deskilo || !handoff)
                OutlinedButton(
                  key: ValueKey('auth-social-${provider.name}'),
                  onPressed: busy ? null : () => onProvider(provider),
                  child: Text(provider.label),
                ),
          ],
        ),
        // #1648 — one explicit Continue with Deskilo, its destination
        // and its true stage; a failure names its own next action.
        if (handoff && offersDeskilo) ...[
          const SizedBox(height: 8),
          FederationHandoffSection(onUseExistingAccount: onUseExistingAccount),
        ],
      ],
    );
  }
}

/// The ways in that are not "I already have a space here" (#1650), below
/// the mode switch so nothing above it moves: an invitation, the
/// organisation's own server and discovery (#2459).
class AuthSecondaryLinks extends StatelessWidget {
  const AuthSecondaryLinks({
    super.key,
    required this.busy,
    required this.joining,
    required this.onJoin,
  });

  final bool busy;
  final bool joining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // #1650 — the two ways in that are not "I already have a
        // space here", below the mode switch so nothing above it
        // moves: an invitation, and the organisation's own server.
        // The invitation itself is pasted AFTER sign-in, on the join
        // form; what is kept now is only that joining is the errand.
        TextButton.icon(
          key: const ValueKey('auth-join'),
          icon: const Icon(Icons.mail_outline),
          label: Text(l10n.authJoinByInvitation),
          onPressed: busy ? null : onJoin,
        ),
        if (joining)
          InlineBanner(
            key: const ValueKey('auth-join-hint'),
            icon: Icons.info_outline,
            severity: InlineBannerSeverity.info,
            text: l10n.authJoinHint,
          ),
        // The explicit secondary path. Reachable signed out, because
        // choosing a server is what comes BEFORE an account on it;
        // setting one up is the wizard on that screen.
        TextButton(
          key: const ValueKey('auth-server'),
          onPressed: () => context.push('/server'),
          child: Text(l10n.authConnectServer),
        ),
        // #2459 — beside Discover, in the same row where it fits.
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton.icon(
              key: const ValueKey('auth-discover'),
              onPressed: () => context.push('/discover'),
              icon: const Icon(Icons.public),
              label: Text(l10n.portalDiscover),
            ),
            const WelcomeLinkButton(),
          ],
        ),
      ],
    );
  }
}
