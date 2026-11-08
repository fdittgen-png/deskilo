// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3402 -- moved to deskilo_invoice_model; this path only re-exports it until the
// sweep PR (#3403) rewrites the importers and deletes it.
// The wrapper(s) below are the only code in this file that read the installed
// snapshot (ActiveTaxReference) or the workspace clock. #3403 sweep: callers
// switch to WorkspaceContext, then the wrapper goes -- not a plain shim delete.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    hide defaultExemptionMention,
    euCountryCode,
    exemptionMentionFor,
    exigibilityMention,
    exportMention,
    frozenTaxPointBasis,
    isEuCountry,
    legalProfileOf,
    looksLikeEuVatId,
    nationalInvoiceMentions,
    qualifyClauses,
    reverseChargeMention,
    supplyVatCategory,
    taxPointsOf,
    vatTaxPointBasis,
    vatTaxPointLedger,
    vatTaxPointPolicy,
    vatTotalsOf;
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' as model
    show defaultExemptionMention, exemptionMentionFor, exigibilityMention, exportMention, looksLikeEuVatId, nationalInvoiceMentions, reverseChargeMention;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart' show TaxReferenceSet;
import '../../../core/vat/tax_reference_active.dart';

export 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    hide defaultExemptionMention,
    euCountryCode,
    exemptionMentionFor,
    exigibilityMention,
    exportMention,
    frozenTaxPointBasis,
    isEuCountry,
    legalProfileOf,
    looksLikeEuVatId,
    nationalInvoiceMentions,
    qualifyClauses,
    reverseChargeMention,
    supplyVatCategory,
    taxPointsOf,
    vatTaxPointBasis,
    vatTaxPointLedger,
    vatTaxPointPolicy,
    vatTotalsOf;

export '../../../core/vat/place_of_supply.dart';

String defaultExemptionMention(
  String countryCode,
  VatRegime regime, {
  String vatId = '',
  String? asOf,
  TaxReferenceSet? reference,
}) => model.defaultExemptionMention(
  countryCode,
  regime,
  vatId: vatId,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

bool looksLikeEuVatId(
  String vatId, {
  String? asOf,
  TaxReferenceSet? reference,
}) => model.looksLikeEuVatId(
  vatId,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

String reverseChargeMention(
  String sellerCountry, {
  String? asOf,
  TaxReferenceSet? reference,
}) => model.reverseChargeMention(
  sellerCountry,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

String exportMention(
  String sellerCountry, {
  String? asOf,
  TaxReferenceSet? reference,
}) => model.exportMention(
  sellerCountry,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

String exemptionMentionFor({
  required String category,
  required String sellerCountry,
  required String sellerReason,
  required String buyerReason,
  required VatRegime regime,
  String? asOf,
}) => model.exemptionMentionFor(
  category: category,
  sellerCountry: sellerCountry,
  sellerReason: sellerReason,
  buyerReason: buyerReason,
  regime: regime,
  asOf: asOf,
  reference: ActiveTaxReference.current,
);

String exigibilityMention({
  required VatRegime regime,
  required String sellerCountry,
  required bool onPaymentBasis,
  String? asOf,
  TaxReferenceSet? reference,
}) => model.exigibilityMention(
  regime: regime,
  sellerCountry: sellerCountry,
  onPaymentBasis: onPaymentBasis,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

List<String> nationalInvoiceMentions({
  required String sellerCountry,
  required VatRegime regime,
  required String currency,
  required int untaxedCents,
  required bool correction,
  String rectifies = '',
  String correctionReason = '',
  String sellerVatId = '',
  String sellerLegalId = '',
  bool qstCharged = false,
}) => model.nationalInvoiceMentions(
  sellerCountry: sellerCountry,
  regime: regime,
  currency: currency,
  untaxedCents: untaxedCents,
  correction: correction,
  rectifies: rectifies,
  correctionReason: correctionReason,
  sellerVatId: sellerVatId,
  sellerLegalId: sellerLegalId,
  qstCharged: qstCharged,
  reference: ActiveTaxReference.current,
);
