// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 -- the nine HMRC boxes of a prepared UK VAT return, in ONE place: the
// MTD bridging CSV and the application's "Submit through MTD" screen both read
// them from here (the application's `mtd_boxes.dart` delegates), so the file
// the person hands to bridging software and the return the app submits cannot
// disagree. Moved here from the application (#3333).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

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
bool _isWhole(String field) => mtdBoxFields.indexOf(field) >= 5;

/// The nine boxes of the filled form [boxes] in CENTS (boxes 6-9 are whole
/// pounds, so multiples of 100), keyed by HMRC's field names.
Map<String, int> mtdBoxCentsOf(List<FilingBox> boxes) {
  final cents = <String, int>{};
  for (final box in boxes) {
    if (box.hasBase && box.baseKey.isNotEmpty) {
      cents[box.baseKey] = (box.netCents ~/ 100) * 100;
    }
    if (box.hasTax && box.taxKey.isNotEmpty) cents[box.taxKey] = box.vatCents;
  }
  return {for (final f in mtdBoxFields) f: cents[f] ?? 0};
}

/// One box as the CSV writes it: pounds and pence, or whole pounds.
String mtdBoxText(String field, int cents) {
  if (_isWhole(field)) return (cents ~/ 100).toString();
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${twoDigits(abs % 100)}';
}

/// Whether [field] is one of boxes 6-9 (whole pounds).
bool mtdBoxIsWhole(String field) => _isWhole(field);
