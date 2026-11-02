// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the UK nine boxes of a prepared return are ONE contract: the Dart
// form catalogue (`vatFormBoxes('GB', …)`, what the bridging CSV and the
// screen show) and the edge function that submits to HMRC
// (`nineBoxesFromLines`, supabase/functions/_shared/hmrc_boxes.ts) both
// reproduce `contracts/vat/gb_nine_boxes.json`. Rewrite the file with
// `UPDATE_GB_NINE_BOXES=1 flutter test test/features/money/vat_gb_nine_boxes_contract_test.dart`
// only for a deliberate change of the form.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:flutter_test/flutter_test.dart';

const _order = [
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

final _cases = <String, List<Map<String, Object?>>>{
  'sales and purchases': [
    {'percent': 20, 'gross_cents': 126600, 'net_cents': 105500, 'vat_cents': 21100, 'invoice_count': 4, 'category': 'S'},
    {'percent': 0, 'gross_cents': 33399, 'net_cents': 33399, 'vat_cents': 0, 'invoice_count': 1, 'category': 'Z'},
    {'percent': 20, 'gross_cents': 28800, 'net_cents': 24000, 'vat_cents': 4800, 'invoice_count': 2, 'direction': 'input', 'category': 'S'},
  ],
  'a credit note, an acquisition and a correction': [
    {'percent': 20, 'gross_cents': 60000, 'net_cents': 50000, 'vat_cents': 10000, 'invoice_count': 3, 'category': 'S'},
    {'percent': 20, 'gross_cents': -12000, 'net_cents': -10000, 'vat_cents': -2000, 'invoice_count': 1, 'category': 'S'},
    {'percent': 20, 'gross_cents': 6000, 'net_cents': 5000, 'vat_cents': 1000, 'invoice_count': 1, 'category': 'acquisition'},
    {'percent': 5, 'gross_cents': 10500, 'net_cents': 10000, 'vat_cents': 500, 'invoice_count': 1, 'direction': 'input', 'category': 'S'},
  ],
  'a repayment': [
    {'percent': 20, 'gross_cents': 12000, 'net_cents': 10099, 'vat_cents': 1901, 'invoice_count': 1, 'category': 'S'},
    {'percent': 20, 'gross_cents': 90000, 'net_cents': 75099, 'vat_cents': 14901, 'invoice_count': 5, 'direction': 'input', 'category': 'S'},
  ],
  'a purchase credit note and a correction': [
    {'percent': 20, 'gross_cents': 24000, 'net_cents': 20000, 'vat_cents': 4000, 'invoice_count': 2, 'category': 'S'},
    {'percent': 20, 'gross_cents': 3600, 'net_cents': 3000, 'vat_cents': 600, 'invoice_count': 1, 'category': 'S', 'correction': true, 'corrects': 'R-2025-4', 'corrects_start': '2025-10-01', 'corrects_end': '2025-12-31'},
    {'percent': 20, 'gross_cents': -24000, 'net_cents': -20000, 'vat_cents': -4000, 'invoice_count': 1, 'direction': 'input', 'category': 'S'},
    {'percent': 20, 'gross_cents': 6000, 'net_cents': 5000, 'vat_cents': 1000, 'invoice_count': 3, 'direction': 'input', 'category': 'S'},
  ],
  'nothing': [],
};


Map<String, num> _boxesOf(List<Map<String, Object?>> raw) {
  final lines = [for (final l in raw) VatDeclarationLine.fromJson(l)];
  final values = <String, num>{};
  for (final box in vatFormBoxes('GB', lines, periodEnd: DateTime(2026, 3, 31))) {
    if (box.hasBase && box.baseKey.isNotEmpty) values[box.baseKey] = box.netCents ~/ 100;
    if (box.hasTax && box.taxKey.isNotEmpty) values[box.taxKey] = box.vatCents / 100;
  }
  return {for (final k in _order) k: values[k] ?? 0};
}

void main() {
  const path = 'contracts/vat/gb_nine_boxes.json';
  test('the nine boxes of the shared cases are the contract file\'s', () {
    final computed = [
      for (final e in _cases.entries) {'name': e.key, 'lines': e.value, 'boxes': _boxesOf(e.value)},
    ];
    final document = {
      'note': 'The UK nine boxes of the prepared lines, as vatFormBoxes(GB) computes them; the Dart test and the edge function both reproduce these.',
      'cases': computed,
    };
    if (Platform.environment['UPDATE_GB_NINE_BOXES'] == '1') {
      File(path).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(document)}\n');
    }
    expect(jsonDecode(File(path).readAsStringSync()), jsonDecode(jsonEncode(document)));
  });
}
