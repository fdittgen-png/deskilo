// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3403 -- the invoice-model questions that take the tax reference as a
// parameter, asked of the snapshot the test installed (`ActiveTaxReference`).
// Tests state the rule under test, not the plumbing of a reference.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

extension InstalledLegalTaxPoint on InvoiceLegal {
  VatTaxPointBasis taxPointBasis(String country) =>
      taxPointBasisOf(this, country, reference: ActiveTaxReference.current);

  String exigibilityIn(String country) =>
      exigibilityOf(this, country, reference: ActiveTaxReference.current);
}

extension InstalledInvoiceBreakdown on Invoice {
  List<InvoiceVatTotal> vatBreakdown({required String zeroCategory}) =>
      vatBreakdownOf(
        this,
        zeroCategory: zeroCategory,
        reference: ActiveTaxReference.current,
      );
}

LegalClauseSnapshot legalClauseSnapshotLive({
  required InvoiceLegal legal,
  required String sellerCountry,
  String buyerCountry = '',
  PaymentTerms? memberTerms,
  String? memberCapacity,
}) => LegalClauseSnapshot.live(
  legal: legal,
  sellerCountry: sellerCountry,
  buyerCountry: buyerCountry,
  memberTerms: memberTerms,
  memberCapacity: memberCapacity,
  reference: ActiveTaxReference.current,
);
