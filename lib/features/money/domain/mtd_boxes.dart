// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the nine HMRC boxes of a prepared UK VAT return, in ONE place:
// the MTD bridging CSV and the "Submit through MTD" screen both read them
// from here, so the file the person hands to bridging software and the
// return the app submits cannot disagree. The edge function recomputes the
// same boxes from the declaration's lines (`supabase/functions/_shared/
// hmrc_boxes.ts`; the shared case file is contracts/vat/gb_nine_boxes.json)
// and refuses any difference.
import 'vat_declaration.dart';

/// The HMRC field names of the nine boxes, in the order of the form.
const mtdBoxFields = [
  'vatDueSales',
  'vatDueAcquisitions',
  'totalVatDue',
  'vatReclaimedCurrPeriod',
  'netVatDue',
  'totalValueSalesExVAT',
  'totalValuePurchasesExVAT',
  'totalValueGoodsSuppliedExVAT',
  'totalAcquisitionsExVAT',
];

/// Boxes 1-5 are in pounds with pence; boxes 6-9 in whole pounds.
bool mtdBoxIsWhole(String field) => mtdBoxFields.indexOf(field) >= 5;

/// The nine boxes of [declaration] in CENTS (boxes 6-9 are whole pounds, so
/// multiples of 100), keyed by HMRC's field names.
Map<String, int> mtdBoxCents(VatDeclaration declaration) {
  final cents = <String, int>{};
  for (final box in vatFormBoxes(
    'GB',
    declaration.lines,
    periodEnd: declaration.periodEnd,
  )) {
    if (box.hasBase && box.baseKey.isNotEmpty) {
      cents[box.baseKey] = (box.netCents ~/ 100) * 100;
    }
    if (box.hasTax && box.taxKey.isNotEmpty) cents[box.taxKey] = box.vatCents;
  }
  return {for (final f in mtdBoxFields) f: cents[f] ?? 0};
}

/// One box as the CSV writes it: pounds and pence, or whole pounds.
String mtdBoxText(String field, int cents) {
  if (mtdBoxIsWhole(field)) return (cents ~/ 100).toString();
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}

/// The boxes as the submission sends them: pounds as numbers (boxes 6-9
/// whole), exactly the values [mtdBoxText] writes.
Map<String, num> mtdBoxPounds(VatDeclaration declaration) => {
  for (final e in mtdBoxCents(declaration).entries)
    e.key: mtdBoxIsWhole(e.key) ? e.value ~/ 100 : e.value / 100,
};
