// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3402 -- moved to deskilo_invoice_model; this path re-exports it until the
// sweep PR (#3403) rewrites the importers and deletes it.
//
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
    show euCountryCode, euMemberStatesOf, isEuCountry, supplyVatCategory;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart' show TaxReferenceSet;
import 'tax_reference_active.dart';

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

/// #2354 -- the member states, ONE set for the whole app (the rows of the
/// `eu_member` domain of the installed tax reference).
Set<String> get euMemberStates =>
    model.euMemberStatesOf(ActiveTaxReference.current);

String euCountryCode(String code, {TaxReferenceSet? reference}) =>
    model.euCountryCode(code, reference: reference ?? ActiveTaxReference.current);

bool isEuCountry(String code, {TaxReferenceSet? reference}) =>
    model.isEuCountry(code, reference: reference ?? ActiveTaxReference.current);

String supplyVatCategory({
  required VatTreatment treatment,
  required SupplyClass supply,
  required bool sellerVatRegistered,
  required String sellerCountry,
  required String buyerCountry,
  required String buyerCapacity,
  bool reverseChargeOn = true,
}) => model.supplyVatCategory(
  treatment: treatment,
  supply: supply,
  sellerVatRegistered: sellerVatRegistered,
  sellerCountry: sellerCountry,
  buyerCountry: buyerCountry,
  buyerCapacity: buyerCapacity,
  reverseChargeOn: reverseChargeOn,
  reference: ActiveTaxReference.current,
);
