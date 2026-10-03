// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — what a refused connection request means for the person
// looking at it. The consent functions (0276, 0342) and Auth answer a
// refusal as a sentence; the screen used to show nothing (approve) or
// "could not be loaded" (load). Each known sentence becomes the one thing
// to do next and who does it. An unknown error stays generic: nothing is
// guessed from it.
import '../../../l10n/app_localizations.dart';
import '../application/consent_refusal.dart';

export '../application/consent_refusal.dart';

String mcpConsentRefusalText(
  AppLocalizations? l10n,
  McpConsentRefusal r,
) => switch (r) {
  McpConsentRefusal.clientNotApproved =>
    l10n?.mcpRefusalClientNotApproved ??
        'This assistant is not approved on this server yet. The operator '
            'approves each assistant once; ask them, then connect again '
            'from the assistant.',
  McpConsentRefusal.notEligible =>
    l10n?.mcpRefusalNotEligible ??
        'Your access to assistants is not approved yet. Ask for it in '
            'DesKilo under Assistants, then connect again from the '
            'assistant.',
  McpConsentRefusal.linkGoogle => l10n?.mcpNextLinkGoogle ?? 'Assistants use your Google sign-in. Link Google to this account first; without it the account cannot use assistants.',
  McpConsentRefusal.signInWithGoogle =>
    l10n?.mcpNextSignInGoogle ??
        'Assistants use your Google sign-in. Sign in with Google to continue.',
  McpConsentRefusal.noIdentity =>
    l10n?.mcpRefusalNoIdentity ??
        'Confirm your identity in DesKilo under Assistants first, then '
            'connect again from the assistant.',
  McpConsentRefusal.offerChanged =>
    l10n?.mcpRefusalOfferChanged ??
        'What this workspace offers changed while you were choosing. '
            'Connect again from the assistant to see the current offer.',
  McpConsentRefusal.requestExpired =>
    l10n?.mcpRefusalRequestExpired ??
        'This connection request has expired or was already used. Start '
            'again from the assistant.',
};
