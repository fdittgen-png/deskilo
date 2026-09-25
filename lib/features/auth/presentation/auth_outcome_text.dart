// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/auth_outcome.dart';

/// The sentence an [AuthResult] earns on screen, with its next step —
/// or null when the outcome needs none (a session exists, the router
/// takes over).
///
/// One place, so the sign-in form and the recovery sheet cannot drift:
/// wrong credentials, an unconfirmed address, a spent code, a rate limit,
/// a disabled provider and a dead network are six different sentences
/// (#1649), and never the server's own words, which may quote what was
/// typed.
String? authOutcomeText(AuthResult result, AppLocalizations? l10n) =>
    switch (result.outcome) {
      AuthOutcome.authenticated || AuthOutcome.completed => null,
      AuthOutcome.verificationRequired =>
        l10n?.authVerifyTitle ?? 'Check your e-mail',
      AuthOutcome.recoveryVerificationRequired =>
        l10n?.authResetCodeSent ?? 'Code sent — check your email.',
      AuthOutcome.recoverySessionReadyButPasswordNotUpdated =>
        l10n?.authRecoveryNotSaved ??
            'Your code was accepted, but the new password was not saved. '
                'Try saving it again.',
      AuthOutcome.rateLimited =>
        l10n?.authRateLimited ?? 'Too many attempts. Wait a moment, then '
            'try again.',
      AuthOutcome.unavailable => l10n?.authNetworkError ??
          'Could not reach the server. Check your connection and try again.',
      AuthOutcome.refused => switch (result.refusal) {
          AuthRefusal.emailNotConfirmed => l10n?.authEmailNotConfirmed ??
              'Confirm your e-mail address first: open the message we sent '
                  'you, then sign in.',
          AuthRefusal.providerDisabled => l10n?.authProviderDisabled ??
              'This sign-in method is switched off on this server.',
          AuthRefusal.alreadyRegistered => l10n?.authAlreadyRegistered ??
              'This address cannot be used to create an account. Sign in '
                  'or reset your password instead.',
          AuthRefusal.weakPassword =>
            l10n?.authWeakPassword ?? 'Choose a stronger password.',
          AuthRefusal.codeInvalid => l10n?.authResetInvalidCode ??
              'That code is invalid or expired.',
          AuthRefusal.credentials || null => l10n?.authGenericError ??
              'Authentication failed. Check your credentials and try again.',
        },
    };
