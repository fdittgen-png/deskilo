// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- how an invoice of a seller in the United States reads: prices are
// quoted net and the tax is stated apart, per jurisdiction, with no VAT wording.
import 'invoice.dart';

extension InvoiceSalesTax on Invoice {
  /// Priced by a sales tax: some total carries a jurisdiction.
  bool get isSalesTax => vatTotals.any((total) => total.isSalesTax);

  /// The price [line] quotes: its net on a sales-tax invoice, else its amount.
  int quotedCents(InvoiceLine line) =>
      isSalesTax ? line.netCents ?? line.amountCents : line.amountCents;
}
