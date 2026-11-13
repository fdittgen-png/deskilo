// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3616 (desk M3) — the documents behind each box of a VAT return, and the
// truth when they no longer agree with it (the decision on #3616). The
// return's boxes come from the jurisdiction package, filled from the
// declaration's lines. "Documents today" are the period's tax points read
// again from the issued invoices by the same engine the return was built
// with, put through the same form, so a rounding of the form is never a
// difference. A box is compared only where every line feeding it is a plain
// sale (no category, no correction, not a purchase): the others are made of
// documents this reading does not hold, and say so instead of a sum.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    show VatTaxPointAmount, vatDeclarationLinesOf;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart'
    show TaxReferenceSet;
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';

/// What one box of a return says, and what its documents say today.
class VatBoxDocuments {
  const VatBoxDocuments({
    required this.box,
    required this.documents,
    required this.today,
  });

  /// The box as the return declared it.
  final VatFormBox box;

  /// The tax points behind the box, at the rates that feed it.
  final List<VatTaxPointAmount> documents;

  /// The box filled from the documents today; null when the box is not
  /// compared (it is made of purchases, a category or a correction).
  final VatFormBox? today;

  /// The box's declared figure: its base where it has one, else its tax.
  int get declared => box.hasBase ? box.netCents : box.vatCents;

  /// The same figure from the documents today; null when not compared.
  int? get documented =>
      today == null ? null : (box.hasBase ? today!.netCents : today!.vatCents);

  /// What changed since the return: documents today minus declared; null
  /// when not compared, zero when they agree.
  int? get difference => documented == null ? null : documented! - declared;
}

/// Whether [line] is a plain sale: what the issued invoices alone make.
bool _plainSale(VatDeclarationLine line) =>
    !line.isInput && !line.isCorrection && line.category.isEmpty;

/// The boxes of [declaration] with their documents today, from the
/// period's tax points [ledger] read again.
List<VatBoxDocuments> vatBoxDocuments(
  VatDeclaration declaration,
  List<VatTaxPointAmount> ledger, {
  required String country,
  required TaxReferenceSet reference,
}) {
  final start = declaration.periodStart;
  final end = declaration.periodEnd;
  final inPeriod = [
    for (final a in ledger)
      if (a.within(start, end)) a,
  ];
  List<VatFormBox> fill(List<VatDeclarationLine> lines) => vatFormBoxes(
    country,
    lines,
    periodEnd: end,
    reference: reference,
  );
  final declared = fill(declaration.lines);
  final today = {
    for (final b in fill(vatDeclarationLinesOf(inPeriod, start, end)))
      b.code: b,
  };
  // Which declared lines feed which box: each line through the form alone.
  final feeding = <String, List<VatDeclarationLine>>{};
  for (final line in declaration.lines) {
    for (final b in fill([line])) {
      if (b.netCents != 0 || b.vatCents != 0) {
        (feeding[b.code] ??= []).add(line);
      }
    }
  }
  return [
    for (final box in declared)
      () {
        final lines = feeding[box.code] ?? const <VatDeclarationLine>[];
        final rates = {for (final l in lines) l.percent};
        final compared = lines.isNotEmpty && lines.every(_plainSale);
        return VatBoxDocuments(
          box: box,
          documents: [
            for (final a in inPeriod)
              if (rates.contains(a.percent)) a,
          ],
          today: compared ? today[box.code] ?? _empty(box) : null,
        );
      }(),
  ];
}

/// [box] with nothing in it: the documents today hold none of its rates.
VatFormBox _empty(VatFormBox box) => VatFormBox(
  code: box.code,
  label: box.label,
  netCents: 0,
  vatCents: 0,
  hasBase: box.hasBase,
  hasTax: box.hasTax,
  baseKey: box.baseKey,
  taxKey: box.taxKey,
);
