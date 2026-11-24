// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the words for what a seller in the United States is missing before
// an invoice can be issued (stable server keys, 0434). Every other key is its
// own text: a key this app does not know is shown as itself.
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice_missing.dart';

/// #1916 — the words for one missing essential (stable server keys, 0365);
/// #2362 sales tax, #2363 a site outside VAT, #4105 the region (0792).
String invoiceMissingLabel(AppLocalizations l10n, String key) =>
    switch (InvoiceMissing.fromWire(key)) {
      InvoiceMissing.salesTaxRateUnset => l10n.invoiceMissingSalesTaxRate,
      InvoiceMissing.salesTaxTaxabilityUnset => l10n.invoiceMissingSalesTaxTaxability,
      InvoiceMissing.territoryOutsideVat => l10n.invoiceMissingTerritoryOutsideVat,
      InvoiceMissing.invoiceFeatureDisabled => l10n.invoiceFeatureDisabled,
      InvoiceMissing.exemptionReason => l10n.invoiceMissingExemptionReason,
      InvoiceMissing.vatNationalCurrency => l10n.invoiceMissingNationalCurrency,
      InvoiceMissing.correctionReason => l10n.invoiceMissingCorrectionReason,
      InvoiceMissing.vatRateUnresolved => l10n.invoiceMissingVatRate,
      InvoiceMissing.vatLineZeroUnexplained => l10n.invoiceMissingVatZeroLine,
      InvoiceMissing.vatChargedNotRegistered => l10n.invoiceMissingVatNotRegistered,
      InvoiceMissing.vatTreatmentUnreviewed => l10n.invoiceMissingVatTreatment,
      InvoiceMissing.viesUnverified => l10n.invoiceMissingVies,
      InvoiceMissing.sellerRegion ||
      InvoiceMissing.sellerAddress ||
      InvoiceMissing.sellerVatId ||
      InvoiceMissing.sellerCountryUnsupported ||
      InvoiceMissing.sellerTaxNumber ||
      InvoiceMissing.sellerVatIdFormat ||
      InvoiceMissing.sellerUidFormat ||
      InvoiceMissing.sellerBnFormat ||
      InvoiceMissing.sellerQstNumber =>
        _sellerMissingLabel(l10n, InvoiceMissing.fromWire(key)),
      InvoiceMissing.buyerRegion ||
      InvoiceMissing.buyerName ||
      InvoiceMissing.buyerAddress ||
      InvoiceMissing.buyerVatId ||
      InvoiceMissing.buyerTaxId ||
      InvoiceMissing.buyerCapacityUnknown =>
        _buyerMissingLabel(l10n, InvoiceMissing.fromWire(key)),
      InvoiceMissing.unknown => key,
    };

/// The business's own missing facts (`seller_*`).
String _sellerMissingLabel(AppLocalizations l10n, InvoiceMissing missing) =>
    switch (missing) {
      InvoiceMissing.sellerRegion => l10n.invoiceMissingSellerRegion,
      InvoiceMissing.sellerAddress => l10n.invoiceMissingSellerAddress,
      InvoiceMissing.sellerVatId => l10n.invoiceMissingSellerVatId,
      InvoiceMissing.sellerCountryUnsupported => l10n.invoiceMissingSellerCountry,
      InvoiceMissing.sellerTaxNumber => l10n.invoiceMissingSellerTaxNumber,
      InvoiceMissing.sellerVatIdFormat => l10n.invoiceMissingSellerVatIdFormat,
      InvoiceMissing.sellerUidFormat => l10n.invoiceMissingSellerUidFormat,
      InvoiceMissing.sellerBnFormat => l10n.invoiceMissingSellerBnFormat,
      InvoiceMissing.sellerQstNumber => l10n.invoiceMissingSellerQstNumber,
      _ => missing.wire,
    };

/// The customer's missing facts (`buyer_*`).
String _buyerMissingLabel(AppLocalizations l10n, InvoiceMissing missing) =>
    switch (missing) {
      InvoiceMissing.buyerRegion => l10n.invoiceMissingBuyerRegion,
      InvoiceMissing.buyerName => l10n.invoiceMissingBuyerName,
      InvoiceMissing.buyerAddress => l10n.invoiceMissingBuyerAddress,
      InvoiceMissing.buyerVatId => l10n.invoiceMissingBuyerVatId,
      InvoiceMissing.buyerTaxId => l10n.invoiceMissingBuyerTaxId,
      InvoiceMissing.buyerCapacityUnknown => l10n.invoiceMissingBuyerCapacity,
      _ => missing.wire,
    };
