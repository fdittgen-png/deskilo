// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3405 -- the one place a VAT declaration is built FROM ISSUED INVOICES. It
// was a function of `vat_declaration.dart`; split out so the declaration model
// (lines, boxes, forms, XML) no longer imports the invoice model and can move
// into a package of its own.
import 'vat_declaration.dart';
import 'vat_tax_point.dart';

/// Aggregates a period's ISSUED invoices into declaration lines — the
/// tax-point engine on the invoice-date rule (`vat_tax_point.dart`),
/// with the EXACT arithmetic the invoices were built with: per-line
/// `vatSplit`, summed per rate, so the lines match every issued document
/// to the cent. Voided invoices and settlements are excluded; credit
/// notes count with their sign. A declaration on another basis reads
/// [vatDeclarationLinesOf] over [vatTaxPointLedger] with that basis.
List<VatDeclarationLine> computeVatDeclarationLines(
  Iterable<Invoice> invoices,
  DateTime periodStart,
  DateTime periodEnd,
) =>
    vatDeclarationLinesOf(
        vatTaxPointLedger(invoices), periodStart, periodEnd);
