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
String? authOutcomeText(AuthResult result, AppLocalizations l10n) =>
    switch (result.outcome) {
      AuthOutcome.authenticated || AuthOutcome.completed => null,
      AuthOutcome.verificationRequired =>
        l10n.authVerifyTitle,
      AuthOutcome.recoveryVerificationRequired =>
        l10n.authResetCodeSent,
      AuthOutcome.recoverySessionReadyButPasswordNotUpdated =>
        l10n.authRecoveryNotSaved,
      AuthOutcome.rateLimited =>
        l10n.authRateLimited,
      AuthOutcome.unavailable => l10n.authNetworkError,
      AuthOutcome.refused => switch (result.refusal) {
          AuthRefusal.emailNotConfirmed => l10n.authEmailNotConfirmed,
          AuthRefusal.providerDisabled => l10n.authProviderDisabled,
          AuthRefusal.alreadyRegistered => l10n.authAlreadyRegistered,
          AuthRefusal.weakPassword =>
            l10n.authWeakPassword,
          AuthRefusal.codeInvalid => l10n.authResetInvalidCode,
          AuthRefusal.credentials || null => l10n.authGenericError,
        },
    };
