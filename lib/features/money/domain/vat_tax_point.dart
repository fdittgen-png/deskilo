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
    show frozenTaxPointBasis, taxPointsOf, vatTaxPointLedger;
import 'package:meta/meta.dart';
import '../../../core/time/workspace_time.dart';
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
export 'vat_tax_point_policy.dart';

@visibleForTesting
List<VatTaxPointAmount> taxPointsOf(
  Invoice invoice,
  List<TaxPointPayment> payments, {
  required VatTaxPointBasis basis,
  DateTime Function(DateTime instant) dayOf = WorkspaceTime.dateOf,
}) => model.taxPointsOf(
  invoice,
  payments,
  basis: basis,
  reference: ActiveTaxReference.current,
  dayOf: dayOf,
);

@visibleForTesting
VatTaxPointBasis frozenTaxPointBasis(Invoice invoice, VatTaxPointBasis basis) =>
    model.frozenTaxPointBasis(
      invoice,
      basis,
      reference: ActiveTaxReference.current,
    );

List<VatTaxPointAmount> vatTaxPointLedger(
  Iterable<Invoice> invoices, {
  Map<String, InvoiceMatch> matches = const {},
  Map<String, List<TaxPointPayment>> instalments = const {},
  VatTaxPointBasis basis = VatTaxPointBasis.invoiceDate,
  DateTime Function(DateTime instant) dayOf = WorkspaceTime.dateOf,
}) => model.vatTaxPointLedger(
  invoices,
  matches: matches,
  instalments: instalments,
  basis: basis,
  reference: ActiveTaxReference.current,
  dayOf: dayOf,
);
