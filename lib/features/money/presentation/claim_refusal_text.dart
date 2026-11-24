// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — each refusal of a payment's claim in its own words: what was
// refused and what the person can do, never a general error. Nothing was
// charged or recorded when one is shown.
import '../../../l10n/app_localizations.dart';
import '../domain/payment_claims.dart';

String claimRefusalText(AppLocalizations l10n, ClaimRefusal r) => switch (r) {
  ClaimRefusal.empty => l10n.claimRefusedEmpty,
  ClaimRefusal.notYours => l10n.claimRefusedNotYours,
  ClaimRefusal.months => l10n.claimRefusedMonths,
  ClaimRefusal.otherMonth => l10n.claimRefusedOtherMonth,
  ClaimRefusal.cannotTake => l10n.claimRefusedCannotTake,
  ClaimRefusal.alreadyInPayment => l10n.claimRefusedAlreadyInPayment,
  ClaimRefusal.amount => l10n.claimRefusedAmount,
  ClaimRefusal.notMyPayment => l10n.claimRefusedNotMyPayment,
  ClaimRefusal.nothingToFree => l10n.claimRefusedNothingToFree,
  ClaimRefusal.notProcessing => l10n.claimRefusedNotProcessing,
  ClaimRefusal.currency => l10n.claimRefusedCurrency,
  ClaimRefusal.withdrawn => l10n.claimRefusedWithdrawn,
  ClaimRefusal.decided => l10n.claimRefusedDecided,
  ClaimRefusal.requestChanged => l10n.claimRefusedRequestChanged,
  ClaimRefusal.standaloneInMonthly => l10n.claimRefusedStandaloneInMonthly,
  ClaimRefusal.monthlyInStandalone => l10n.claimRefusedMonthlyInStandalone,
  ClaimRefusal.other => l10n.claimRefusedOther,
};
