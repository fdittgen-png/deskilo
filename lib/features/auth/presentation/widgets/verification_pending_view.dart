// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/sign_up_verification.dart';
import '../../domain/auth_outcome.dart';
import '../auth_outcome_text.dart';

/// Where a sign-up lands when the server sent an e-mail instead of a
/// session (#1649): the address it went to, what to do, and the three
/// ways on — send it again, use another address, go back to sign-in.
///
/// A state, not a snackbar: the person is about to leave for their mail
/// app, and what they come back to must still say what they are waiting
/// for. It says the message was SENT, never that it arrived or that the
/// account is confirmed — sending is all the server vouched for.
///
/// The instance wizard leaves the confirmation template link-based
/// (`mailer_autoconfirm: false`, no `{{ .Token }}`), so there is no code
/// to type here and no code field: a field for a code the e-mail does not
/// contain would be a trap.
class VerificationPendingView extends ConsumerStatefulWidget {
  const VerificationPendingView({
    super.key,
    required this.email,
    required this.onChangeEmail,
    required this.onBackToSignIn,
  });

  /// The address the e-mail went to — shown, so a typo is visible.
  final String email;

  /// Back to the sign-up form with the address editable; the sign-up
  /// intent that sent the e-mail is abandoned, nothing is deleted.
  final VoidCallback onChangeEmail;

  final VoidCallback onBackToSignIn;

  @override
  ConsumerState<VerificationPendingView> createState() =>
      _VerificationPendingViewState();
}

class _VerificationPendingViewState
    extends ConsumerState<VerificationPendingView> {
  bool _busy = false;
  AuthResult? _lastResult;

  /// The sign-up itself just sent one, so the offer starts closed and
  /// opens when a send could succeed. One timer flips it back; nothing
  /// ticks per second, so nothing is announced per second.
  bool _coolingDown = false;
  Timer? _cooldown;

  @override
  void initState() {
    super.initState();
    _arm(AuthCooldowns.resend);
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    super.dispose();
  }

  void _arm(Duration wait) {
    _cooldown?.cancel();
    _coolingDown = true;
    _cooldown = Timer(wait, () {
      if (mounted) setState(() => _coolingDown = false);
    });
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _lastResult = null;
    });
    final turn =
        await ref.read(signUpVerificationProvider).resend(widget.email);
    // The person may have gone to change the address meanwhile; a late
    // answer then has no view to land in.
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastResult = turn.result;
      if (turn.holdFor case final wait?) _arm(wait);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = _lastResult;
    final sentAgain = result?.outcome == AuthOutcome.verificationRequired;
    final deferred = result?.outcome == AuthOutcome.rateLimited;
    final banner = result == null
        ? null
        : sentAgain
            ? (l10n?.authVerifyResent ?? 'Sent again.')
            : authOutcomeText(result, l10n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n?.authVerifyTitle ?? 'Check your e-mail',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          key: const ValueKey('verify-body'),
          l10n?.authVerifyBody(widget.email) ??
              'We sent a confirmation link to ${widget.email}. Open it on '
                  'this device to finish creating your account.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n?.authVerifyHint ??
              'Nothing yet? Look in the spam folder, or send it again.',
          style: theme.textTheme.bodySmall,
        ),
        if (banner != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineBanner(
            key: const ValueKey('verify-outcome'),
            icon: sentAgain
                ? Icons.mark_email_unread_outlined
                : deferred
                    ? Icons.hourglass_top_outlined
                    : Icons.error_outline,
            // Sent and deferred are both "wait", not "you did wrong".
            severity: sentAgain || deferred
                ? InlineBannerSeverity.info
                : InlineBannerSeverity.error,
            text: banner,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          key: const ValueKey('verify-resend'),
          onPressed: _busy || _coolingDown ? null : _resend,
          child: Text(
            _coolingDown
                ? (l10n?.authVerifyResendWait ??
                    'You can send it again in a minute.')
                : (l10n?.authVerifyResend ?? 'Send the e-mail again'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const ValueKey('verify-change-email'),
          onPressed: widget.onChangeEmail,
          child: Text(l10n?.authVerifyChangeEmail ?? 'Use another address'),
        ),
        TextButton(
          key: const ValueKey('verify-back'),
          onPressed: widget.onBackToSignIn,
          child: Text(l10n?.authVerifyBackToSignIn ?? 'Back to sign in'),
        ),
      ],
    );
  }
}
