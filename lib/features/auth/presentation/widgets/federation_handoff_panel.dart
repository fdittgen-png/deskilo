// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/federation_handoff_controller.dart';
import '../../domain/federation_port.dart';

/// #1648 — the one explicit "Continue with Deskilo" action, the sentence
/// that says where it leads, and the handoff's true stage or next action.
///
/// No embedded page, no password field: the provider's own pages run in
/// the system browser, and this app only says what it actually knows.
class FederationHandoffSection extends ConsumerStatefulWidget {
  const FederationHandoffSection({
    super.key,
    this.link = false,
    this.onUseExistingAccount,
  });

  /// Linking Deskilo to the signed-in account rather than signing in.
  final bool link;

  /// Where "Sign in to my existing account" leads; absent while linking,
  /// where the person is already signed in.
  final VoidCallback? onUseExistingAccount;

  @override
  ConsumerState<FederationHandoffSection> createState() =>
      _FederationHandoffSectionState();
}

class _FederationHandoffSectionState
    extends ConsumerState<FederationHandoffSection>
    with WidgetsBindingObserver {
  final _continueFocus = FocusNode(debugLabel: 'federation-continue');
  bool _details = false;

  FederationHandoffController get _controller =>
      ref.read(federationHandoffControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _continueFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.resumed();
  }

  /// Keyboard and screen-reader focus comes back to the action that
  /// started it, once that action is enabled again.
  void _restoreFocus() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _continueFocus.requestFocus();
  });

  Future<void> _cancel() async {
    await _controller.cancel();
    _restoreFocus();
  }

  void _close() {
    _controller.dismiss();
    _restoreFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final handoff = ref.watch(federationHandoffControllerProvider);
    final mine = handoff.link == widget.link;
    final stage = mine ? handoff.stage : null;
    final failure = mine ? handoff.failure : null;
    final destination = ref.watch(federationDestinationProvider).value;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: ValueKey(widget.link ? 'link-deskilo' : 'auth-social-deskilo'),
          focusNode: _continueFocus,
          onPressed: handoff.busy
              ? null
              : () => unawaited(_controller.start(link: widget.link)),
          child: Text(l10n?.federationContinue ?? 'Continue with Deskilo'),
        ),
        if (destination != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n?.federationPurpose(destination.server) ??
                'Your browser confirms your Deskilo account, then brings '
                    'you back to ${destination.server}.',
            key: const ValueKey('federation-purpose'),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          TextButton(
            key: const ValueKey('federation-details'),
            onPressed: () => setState(() => _details = !_details),
            child: Text(l10n?.federationDetails ?? 'Technical details'),
          ),
          if (_details)
            SelectableText(
              '${l10n?.federationDetailServer(destination.server) ?? 'Server: ${destination.server}'}\n'
              '${l10n?.federationDetailAuthority(destination.authority) ?? 'Identity authority: ${destination.authority}'}',
              key: const ValueKey('federation-detail-lines'),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
        ],
        if (stage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _Stage(stage: stage, onCancel: handoff.cancellable ? _cancel : null),
        ],
        if (failure != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _Failure(
            failure: failure,
            onRetry: () => unawaited(_controller.start(link: widget.link)),
            onClose: _close,
            onReviewServer: widget.link
                ? null
                : () {
                    _controller.dismiss();
                    unawaited(context.push('/server'));
                  },
            onUseExistingAccount: widget.onUseExistingAccount == null
                ? null
                : () {
                    _controller.dismiss();
                    widget.onUseExistingAccount!();
                  },
          ),
        ],
      ],
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.stage, required this.onCancel});
  final FederationStage stage;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (stage) {
      FederationStage.opening =>
        l10n?.federationStageOpening ?? 'Opening sign-in…',
      FederationStage.waiting =>
        l10n?.federationStageWaiting ?? 'Waiting for sign-in in your browser…',
      FederationStage.completing =>
        l10n?.federationStageCompleting ?? 'Completing sign-in…',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Announced as it changes, so a screen reader hears the stage the
        // app is really in; the bar under it names nothing else.
        Semantics(
          liveRegion: true,
          child: Text(
            label,
            key: const ValueKey('federation-stage'),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const ExcludeSemantics(child: LinearProgressIndicator()),
        if (onCancel != null)
          TextButton(
            key: const ValueKey('federation-cancel'),
            onPressed: onCancel,
            child: Text(l10n?.federationCancel ?? 'Cancel'),
          ),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({
    required this.failure,
    required this.onRetry,
    required this.onClose,
    required this.onReviewServer,
    required this.onUseExistingAccount,
  });
  final FederationFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final VoidCallback? onReviewServer;
  final VoidCallback? onUseExistingAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = switch (failure) {
      FederationFailure.wrongAccount =>
        l10n?.federationFailureWrongAccount ??
            'Your browser signed in with a different Deskilo account.',
      FederationFailure.unlinkedAccount =>
        l10n?.federationFailureUnlinked ??
            'This Deskilo account matches an account here that is not '
                'linked to it yet.',
      FederationFailure.incompatibleServer =>
        l10n?.federationFailureIncompatible ??
            'This server does not accept this Deskilo sign-in.',
      FederationFailure.providerMissing =>
        l10n?.federationFailureProviderMissing ??
            'Deskilo sign-in is not set up on this server.',
      FederationFailure.network =>
        l10n?.federationFailureNetwork ?? 'The server could not be reached.',
      FederationFailure.refused =>
        l10n?.federationFailureRefused ??
            'The sign-in was cancelled or refused in the browser.',
      FederationFailure.expired =>
        l10n?.federationFailureExpired ??
            'This sign-in has expired. Start it again.',
      FederationFailure.browserUnavailable =>
        l10n?.federationFailureBrowser ?? 'The browser could not be opened.',
    };
    // Each failure has its own next step. None of them is "create another
    // account": a failed federation is never repaired with a new password.
    final (String, VoidCallback, String)? action = switch (failure) {
      FederationFailure.unlinkedAccount =>
        onUseExistingAccount == null
            ? null
            : (
                l10n?.federationActionExistingAccount ??
                    'Sign in to my existing account',
                onUseExistingAccount!,
                'federation-existing-account',
              ),
      FederationFailure.incompatibleServer =>
        onReviewServer == null
            ? null
            : (
                l10n?.federationActionReviewServer ?? 'Review server',
                onReviewServer!,
                'federation-review-server',
              ),
      FederationFailure.providerMissing => null,
      _ => (l10n?.federationRetry ?? 'Try again', onRetry, 'federation-retry'),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: InlineBanner(
            key: ValueKey('federation-failure-${failure.name}'),
            icon: Icons.error_outline,
            severity: InlineBannerSeverity.error,
            text: text,
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            if (action case (final label, final onPressed, final key))
              TextButton(
                key: ValueKey(key),
                onPressed: onPressed,
                child: Text(label),
              ),
            TextButton(
              key: const ValueKey('federation-close'),
              onPressed: onClose,
              child: Text(l10n?.federationClose ?? 'Close'),
            ),
          ],
        ),
      ],
    );
  }
}
