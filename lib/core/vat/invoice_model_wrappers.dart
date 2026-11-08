// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3402 -- the invoice model's old-path wrappers, in ONE file: the only code
// in the invoice model's neighbourhood that reads the installed snapshot
// (ActiveTaxReference) or the workspace clock (WorkspaceTime). The package
// (deskilo_invoice_model) takes the reference and the day-of function as
// required parameters; these keep the old signatures and pass the globals.
// The old paths (invoice.dart, vat_compliance.dart, ...) re-export this file.
//
// #3403 sweep: callers switch to WorkspaceContext, then THIS FILE goes -- not
// a plain shim delete.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    hide frozenTaxPointBasis,
    isEuCountry,
    legalProfileOf,
    qualifyClauses,
    taxPointsOf,
    vatTaxPointBasis,
    vatTaxPointLedger,
    vatTaxPointPolicy,
    vatTotalsOf;
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' as model
    show LegalClauseSnapshot, euMemberStatesOf, exigibilityOf, frozenTaxPointBasis, isEuCountry, legalProfileOf, qualifyClauses, taxPointBasisOf, taxPointsOf, vatBreakdownOf, vatTaxPointBasis, vatTaxPointLedger, vatTaxPointPolicy, vatTotalsOf;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart' show TaxReferenceSet;
import 'package:meta/meta.dart';

import '../time/workspace_time.dart';
import 'tax_reference_active.dart';

/// #2354 -- the member states, ONE set for the whole app (the rows of the
/// `eu_member` domain of the installed tax reference).
Set<String> get euMemberStates =>
    model.euMemberStatesOf(ActiveTaxReference.current);

bool isEuCountry(String code, {TaxReferenceSet? reference}) =>
    model.isEuCountry(code, reference: reference ?? ActiveTaxReference.current);

@visibleForTesting
LegalProfile legalProfileOf(LegalClauseSnapshot snapshot) =>
    model.legalProfileOf(snapshot, reference: ActiveTaxReference.current);

QualifiedClauses qualifyClauses(
  LegalClauseSnapshot snapshot,
  ReportStrings strings,
) => model.qualifyClauses(
  snapshot,
  strings,
  reference: ActiveTaxReference.current,
);

/// The same facts read from the LIVE settings (statements, letters,
/// previews): `LegalClauseSnapshot.live` with the installed reference.
LegalClauseSnapshot legalClauseSnapshotLive({
  required InvoiceLegal legal,
  required String sellerCountry,
  String buyerCountry = '',
  PaymentTerms? memberTerms,
  String? memberCapacity,
}) => model.LegalClauseSnapshot.live(
  legal: legal,
  sellerCountry: sellerCountry,
  buyerCountry: buyerCountry,
  memberTerms: memberTerms,
  memberCapacity: memberCapacity,
  reference: ActiveTaxReference.current,
);

VatTaxPointPolicy vatTaxPointPolicy(
  String country, {
  String? asOf,
  TaxReferenceSet? reference,
}) => model.vatTaxPointPolicy(
  country,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);

/// The basis of a seller in [country] whose stored choice is [option].
VatTaxPointBasis vatTaxPointBasis(String country, VatTaxPointOption? option) =>
    model.vatTaxPointBasis(
      country,
      option,
      reference: ActiveTaxReference.current,
    );

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

/// The breakdown the documents render, one entry per rate (the snapshot wins
/// whenever there is one): `vatBreakdownOf` with the installed reference.
extension InvoiceVatBreakdown on Invoice {
  List<InvoiceVatTotal> vatBreakdown({required String zeroCategory}) =>
      model.vatBreakdownOf(
        this,
        zeroCategory: zeroCategory,
        reference: ActiveTaxReference.current,
      );
}
