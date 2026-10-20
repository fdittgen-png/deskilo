// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the words for what a seller in the United States is missing before
// an invoice can be issued (stable server keys, 0434). Every other key is its
// own text: `invoiceMissingLabel` falls through to this and then to the key.
import '../../../../l10n/app_localizations.dart';

String _salesTaxMissingLabel(AppLocalizations l10n, String key) => switch (key) {
  'sales_tax_rate_unset' => l10n.invoiceMissingSalesTaxRate,
  'sales_tax_taxability_unset' => l10n.invoiceMissingSalesTaxTaxability,
  _ => key,
};

/// #1916 — the words for one missing essential (stable server keys, 0365).
String invoiceMissingLabel(AppLocalizations l10n, String key) => switch (key) {
      'invoice_feature_disabled' => l10n.invoiceFeatureDisabled,
      'seller_address' => l10n.invoiceMissingSellerAddress,
      'seller_vat_id' => l10n.invoiceMissingSellerVatId,
      'exemption_reason' => l10n.invoiceMissingExemptionReason,
      'buyer_name' => l10n.invoiceMissingBuyerName,
      'buyer_address' => l10n.invoiceMissingBuyerAddress,
      'buyer_vat_id' => l10n.invoiceMissingBuyerVatId,
      'seller_country_unsupported' => l10n.invoiceMissingSellerCountry,
      // #2356 — § 14 UStG / NIF, the customer's identifier, art. 230.
      'seller_tax_number' => l10n.invoiceMissingSellerTaxNumber,
      'buyer_tax_id' => l10n.invoiceMissingBuyerTaxId,
      'vat_national_currency' => l10n.invoiceMissingNationalCurrency,
      // #2359 — HMRC's VAT registration number format.
      'seller_vat_id_format' => l10n.invoiceMissingSellerVatIdFormat,
      // #2360 — the Swiss UID with its MWST suffix.
      'seller_uid_format' => l10n.invoiceMissingSellerUidFormat,
      'seller_bn_format' => l10n.invoiceMissingSellerBnFormat,
      'seller_qst_number' => l10n.invoiceMissingSellerQstNumber,
      // #2440 — RD 1619/2012 art. 15.
      'correction_reason' => l10n.invoiceMissingCorrectionReason,
      'vat_rate_unresolved' => l10n.invoiceMissingVatRate,
      'vat_line_zero_unexplained' => l10n.invoiceMissingVatZeroLine,
      'vat_charged_not_registered' => l10n.invoiceMissingVatNotRegistered,
      'vat_treatment_unreviewed' => l10n.invoiceMissingVatTreatment,
      // #2354 — a general service to a customer abroad: business or not.
      'vies_unverified' =>
        l10n.invoiceMissingVies,
      'buyer_capacity_unknown' =>
        l10n
            .invoiceMissingBuyerCapacity,
      _ => _salesTaxMissingLabel(l10n, key),
    };
