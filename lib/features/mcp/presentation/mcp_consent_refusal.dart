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
  AppLocalizations l10n,
  McpConsentRefusal r,
) => switch (r) {
  McpConsentRefusal.clientNotApproved =>
    l10n.mcpRefusalClientNotApproved,
  McpConsentRefusal.notEligible =>
    l10n.mcpRefusalNotEligible,
  McpConsentRefusal.linkGoogle => l10n.mcpNextLinkGoogle,
  McpConsentRefusal.signInWithGoogle =>
    l10n.mcpNextSignInGoogle,
  McpConsentRefusal.noIdentity =>
    l10n.mcpRefusalNoIdentity,
  McpConsentRefusal.offerChanged =>
    l10n.mcpRefusalOfferChanged,
  McpConsentRefusal.requestExpired =>
    l10n.mcpRefusalRequestExpired,
};
