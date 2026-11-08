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
    show vatTotalsOf;
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

List<InvoiceVatTotal> vatTotalsOf(
  Iterable<({int amountCents, double vatPercent})> lines, {
  required String zeroCategory,
  String sellerCountry = '',
}) => model.vatTotalsOf(
  lines,
  zeroCategory: zeroCategory,
  sellerCountry: sellerCountry,
  reference: ActiveTaxReference.current,
);
