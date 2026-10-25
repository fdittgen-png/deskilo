// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is that the VAT account of a period equals boxes 1 and 4 of its return
//
// #2378 — the UK VAT account (VAT Regulations 1995 reg. 32): output tax and
// input tax per period, corrections of earlier periods apart. Read from the
// return's own lines, its payable side is box 1 and its allowable side box 4
// of the VAT100 for the same quarter.
import 'dart:convert';

import 'package:deskilo/features/money/domain/vat_account.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:flutter_test/flutter_test.dart';

VatDeclarationLine _line(
  double percent,
  int net,
  int vat, {
  String direction = 'output',
  String corrects = '',
  String category = 'S',
}) => VatDeclarationLine(
  percent: percent,
  category: category,
  grossCents: net + vat,
  netCents: net,
  vatCents: vat,
  invoiceCount: 1,
  direction: direction,
  corrects: corrects,
);

VatDeclaration _return(
  DateTime start,
  DateTime end,
  List<VatDeclarationLine> lines, {
  String status = 'filed',
}) => VatDeclaration(
  id: '$start',
  workspaceId: 'w',
  periodStart: start,
  periodEnd: end,
  status: status,
  lines: lines,
  totalNetCents: 0,
  totalVatCents: 0,
  currency: 'GBP',
  invoiceCount: lines.length,
  createdAt: end,
  number: status == 'filed' ? 'DECL-2026-0001' : '',
);

int _box(List<VatFormBox> boxes, String code) =>
    boxes.firstWhere((b) => b.code == code).vatCents;

void main() {
  final q1Lines = [
    _line(20, 100000, 20000),
    _line(5, 40000, 2000),
    _line(0, 5000, 0, category: 'Z'),
    // A credit note of the quarter and a correction of last year's Q4.
    _line(20, -2500, -500),
    _line(20, 1000, 200, corrects: 'DECL-2025-0004'),
    _line(20, 30000, 6000, direction: 'input'),
    _line(20, -500, -100, direction: 'input', corrects: 'DECL-2025-0004'),
  ];
  final q1 = _return(DateTime(2026), DateTime(2026, 3, 31), q1Lines);

  test('the VAT account of Q1 equals boxes 1 and 4 of its return', () {
    final period = buildVatAccount([q1]).single;
    final boxes = vatFormBoxes('GB', q1Lines, periodEnd: q1.periodEnd);
    expect(period.payableCents, _box(boxes, 'Box 1'));
    expect(period.allowableCents, _box(boxes, 'Box 4'));
    expect(period.netCents, _box(boxes, 'Box 1') - _box(boxes, 'Box 4'));
    // The corrections stay apart from the period's own tax.
    expect(period.outputTaxCents, 21500);
    expect(period.outputCorrectionCents, 200);
    expect(period.inputTaxCents, 6000);
    expect(period.inputCorrectionCents, -100);
  });

  test('periods oldest first; a draft an older client wrote is no return', () {
    final q2 = _return(
      DateTime(2026, 4),
      DateTime(2026, 6, 30),
      [_line(20, 5000, 1000)],
      status: 'prepared',
    );
    final draft = _return(
      DateTime(2026, 7),
      DateTime(2026, 9, 30),
      [_line(20, 5000, 1000)],
      status: 'draft',
    );
    final account = buildVatAccount([draft, q2, q1]);
    expect([for (final p in account) p.status], ['filed', 'prepared']);
  });

  test('the CSV states each period, the corrections apart, in pounds', () {
    final csv = buildVatAccountCsv(buildVatAccount([q1]));
    final rows = csv.trim().split('\n');
    expect(
      rows[1],
      'period_start,period_end,return,status,currency,output_tax,'
      'output_corrections,vat_payable,input_tax,input_corrections,'
      'vat_allowable,net_vat',
    );
    expect(
      rows[2],
      '2026-01-01,2026-03-31,"DECL-2026-0001",filed,"GBP",215.00,2.00,'
      '217.00,60.00,-1.00,59.00,158.00',
    );
  });

  test('the archive carries the year\'s account, and nothing without returns', () {
    final files = archiveVatAccount([q1], 2026);
    expect(files.keys, ['vat-account.csv']);
    expect(utf8.decode(files['vat-account.csv']!), contains('2026-01-01,2026-03-31'));
    expect(archiveVatAccount([q1], 2025), isEmpty);
    expect(archiveVatAccount(const [], 2026), isEmpty);
  });
}
