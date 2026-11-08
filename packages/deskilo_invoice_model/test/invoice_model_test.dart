// SPDX-License-Identifier: AGPL-3.0-or-later
// #3402 -- the invoice model stands alone: the tax-point engine and the
// place-of-supply decision are asked with an explicit reference set and day-of
// function. The detailed tests of every rule stay in the application.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:test/test.dart';

void main() {
  test('a tax-point policy is read from the set it is given: an empty one falls back to the invoice date', () {
    final policy = vatTaxPointPolicy('FR', reference: const TaxReferenceSet([]));
    expect(policy.standard, VatTaxPointRule.invoiceDate);
  });

  test('an invoice kind reads its wire name and defaults to the whole month', () {
    expect(InvoiceKind.fromWire('usage'), InvoiceKind.usage);
    expect(InvoiceKind.fromWire('nonsense'), InvoiceKind.full);
    expect(InvoiceKind.subscription.isInAdvance, isTrue);
  });
}
