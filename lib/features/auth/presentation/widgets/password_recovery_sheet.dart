// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/password_recovery.dart';
import '../../domain/auth_outcome.dart';
import '../auth_outcome_text.dart';

/// Opens the forgot-password sheet. Resolves true only when the password
/// was actually updated; dismissing it, at whatever step, resolves false
/// — so the caller can never say "password updated" on a session alone.
Future<bool> showPasswordRecoverySheet(
  BuildContext context, {
  required String email,
}) async {
  final completed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => PasswordRecoverySheet(initialEmail: email),
  );
  return completed ?? false;
}

/// The forgot-password flow: a one-time code is e-mailed and, entered
/// here, is the temporary credential that sets a brand-new password
/// (code-based on purpose — no Site-URL/deep-link fragility). The
/// decisions live in [PasswordRecovery]; this holds the fields, the busy
/// flag, and the words.
class PasswordRecoverySheet extends ConsumerStatefulWidget {
  const PasswordRecoverySheet({super.key, required this.initialEmail});

  final String initialEmail;

  @override
  ConsumerState<PasswordRecoverySheet> createState() =>
      _PasswordRecoverySheetState();
}

class _PasswordRecoverySheetState extends ConsumerState<PasswordRecoverySheet> {
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  late final PasswordRecovery _flow;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
    // Read once: dispose() runs after the element's ref is gone.
    _flow = ref.read(passwordRecoveryProvider);
  }

  @override
  void dispose() {
    unawaited(_flow.abandon());
    // A code and a password are not for keeping, however the sheet went.
    _code.clear();
    _newPassword.clear();
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _primary() async {
    // Enter in a field and the button share this path; one intent, one
    // call, whichever arrives second while the first is in flight.
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    if (_flow.step != RecoveryStep.request && _newPassword.text.length < 8) {
      setState(() =>
          _error = l10n?.authPasswordTooShort ?? 'At least 8 characters');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final turn = await _flow.submit(
      email: _email.text.trim(),
      code: _code.text.trim(),
      newPassword: _newPassword.text,
    );
    // Closed meanwhile: the answer has nowhere to land, and a late
    // "completed" must not navigate a screen that moved on.
    if (!mounted) return;
    if (turn.result.outcome == AuthOutcome.completed) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = switch (turn.notice) {
        RecoveryNotice.none => null,
        RecoveryNotice.outcome => authOutcomeText(turn.result, l10n),
        RecoveryNotice.sessionLost => l10n?.authRecoverySessionLost ??
            'That code is no longer valid here. Request a new one.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final step = _flow.step;
    final atRequest = step == RecoveryStep.request;
    return SheetShell(
      title: l10n?.authResetTitle ?? 'Reset password',
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          switch (step) {
            RecoveryStep.request => l10n?.authResetExplainer ??
                "We'll email you a one-time code. Use it here to set a new "
                    'password.',
            RecoveryStep.verify =>
              l10n?.authResetCodeSent ?? 'Code sent — check your email.',
            RecoveryStep.retryUpdate => l10n?.authRecoveryNotSaved ??
                'Your code was accepted, but the new password was not '
                    'saved. Try saving it again.',
          },
          key: const ValueKey('reset-explainer'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('reset-email'),
          controller: _email,
          enabled: atRequest && !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _primary(),
          decoration: InputDecoration(
            labelText: l10n?.authEmailLabel ?? 'Email',
          ),
        ),
        if (step == RecoveryStep.verify) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('reset-code'),
            controller: _code,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            // One plain field: a manager or the mail app can paste the
            // code whole.
            autofillHints: const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n?.authResetCodeLabel ?? 'Code from the email',
            ),
          ),
        ],
        if (!atRequest) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('reset-password'),
            controller: _newPassword,
            enabled: !_busy,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _primary(),
            decoration: InputDecoration(
              labelText: l10n?.authResetNewPasswordLabel ?? 'New password',
            ),
          ),
        ],
        if (_error case final error?) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineBanner(
            key: const ValueKey('reset-outcome'),
            icon: Icons.error_outline,
            text: error,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const ValueKey('reset-primary'),
          onPressed: _busy ? null : _primary,
          child: Text(switch (step) {
            RecoveryStep.request => l10n?.authResetSendCode ?? 'Send code',
            RecoveryStep.verify =>
              l10n?.authResetSubmit ?? 'Set new password',
            RecoveryStep.retryUpdate => l10n?.authRecoveryRetryUpdate ??
                'Save the new password again',
          }),
        ),
        TextButton(
          key: const ValueKey('reset-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
      ],
    );
  }
}
