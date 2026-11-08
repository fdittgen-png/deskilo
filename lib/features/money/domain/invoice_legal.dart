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
    show exigibilityOf, taxPointBasisOf;
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

/// The reference-reading forms of the tax-point questions on [InvoiceLegal].
extension InvoiceLegalTaxPoint on InvoiceLegal {
  /// The basis a seller in [country] declares on.
  VatTaxPointBasis taxPointBasis(String country) => model.taxPointBasisOf(
    this,
    country,
    reference: ActiveTaxReference.current,
  );

  /// The #896 two-value key for [country]: `payment` when the tax waits
  /// for the money, `invoice` otherwise -- what the printed mention reads.
  String exigibilityIn(String country) => model.exigibilityOf(
    this,
    country,
    reference: ActiveTaxReference.current,
  );
}
