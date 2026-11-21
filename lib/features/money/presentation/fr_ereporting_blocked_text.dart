// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4163 -- what the France e-reporting says when it refuses to write: every
// document it cannot sort or split, with its reason, in the user's language.
// One message per reason, so each sentence is whole in all five languages.
import '../../../l10n/app_localizations.dart';
import '../domain/fr_ereporting_capacity.dart';

String frEReportingBlockedText(
  AppLocalizations l10n,
  List<FrUnresolved> unresolved,
) => l10n.frEReportingBlocked(
  unresolved.map((u) => _document(l10n, u.number, u.reasons.first)).join('; '),
);

String _document(AppLocalizations l10n, String number, FrUnresolvedReason r) =>
    switch (r) {
      FrUnresolvedReason.noFrozenCapacity =>
        l10n.frEReportingDocumentNoFrozenCapacity(number),
      FrUnresolvedReason.capacityUnknown =>
        l10n.frEReportingDocumentCapacityUnknown(number),
      FrUnresolvedReason.buyerCountryMissing =>
        l10n.frEReportingDocumentBuyerCountryMissing(number),
      FrUnresolvedReason.buyerCountryConflict =>
        l10n.frEReportingDocumentBuyerCountryConflict(number),
      FrUnresolvedReason.buyerVatIdMissing =>
        l10n.frEReportingDocumentBuyerVatIdMissing(number),
      FrUnresolvedReason.unsupportedCommercialLine =>
        l10n.frEReportingDocumentUnsupportedCommercialLine(number),
      FrUnresolvedReason.goodsZeroRateUnsupported =>
        l10n.frEReportingDocumentGoodsZeroRateUnsupported(number),
      FrUnresolvedReason.goodsAbroadUnsupported =>
        l10n.frEReportingDocumentGoodsAbroadUnsupported(number),
      FrUnresolvedReason.missingReceiptAllocation =>
        l10n.frEReportingDocumentMissingReceiptAllocation(number),
      FrUnresolvedReason.amountRuleUnsupported =>
        l10n.frEReportingDocumentAmountRuleUnsupported(number),
    };
