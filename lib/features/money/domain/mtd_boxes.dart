// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the nine HMRC boxes of a prepared UK VAT return, in ONE place:
// the MTD bridging CSV and the "Submit through MTD" screen both read them
// from here, so the file the person hands to bridging software and the
// return the app submits cannot disagree. The edge function recomputes the
// same boxes from the declaration's lines (`supabase/functions/_shared/
// hmrc_boxes.ts`; the shared case file is contracts/vat/gb_nine_boxes.json)
// and refuses any difference.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart'
    show FilingBox;
import 'package:deskilo_jurisdiction_gb/deskilo_jurisdiction_gb.dart'
    as gb
    show mtdBoxCentsOf, mtdBoxIsWhole, mtdFormCountry;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart' show TaxReferenceSet;
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';

export 'package:deskilo_jurisdiction_gb/deskilo_jurisdiction_gb.dart'
    show mtdBoxFields, mtdBoxText;

/// The nine boxes of [declaration] in CENTS (boxes 6-9 are whole pounds, so
/// multiples of 100), keyed by HMRC's field names. The arithmetic lives in the
/// British add-on (#3333): this fills the form from the installed tax
/// reference and hands its boxes over.
Map<String, int> mtdBoxCents(
  VatDeclaration declaration, {
  required TaxReferenceSet reference,
}) => gb.mtdBoxCentsOf([
  for (final box in vatFormBoxes(
    gb.mtdFormCountry,
    declaration.lines,
    periodEnd: declaration.periodEnd,
    reference: reference,
  ))
    FilingBox(
      code: box.code,
      label: box.label,
      netCents: box.netCents,
      vatCents: box.vatCents,
      hasBase: box.hasBase,
      hasTax: box.hasTax,
      baseKey: box.baseKey,
      taxKey: box.taxKey,
    ),
]);

/// The boxes as the submission sends them: pounds as numbers (boxes 6-9
/// whole), exactly the values `mtdBoxText` writes.
Map<String, num> mtdBoxPounds(
  VatDeclaration declaration, {
  required TaxReferenceSet reference,
}) => {
  for (final e in mtdBoxCents(declaration, reference: reference).entries)
    e.key: gb.mtdBoxIsWhole(e.key) ? e.value ~/ 100 : e.value / 100,
};
