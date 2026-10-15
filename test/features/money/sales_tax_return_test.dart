// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the sales-tax summary: the rows of the server function decode (pgTAP
// 191 proves what it states) and the worksheet CSV keeps the figures the owner
// keys into the state portal.
import 'package:deskilo/core/demo/data/sales_tax_repository.dart';
import 'package:deskilo/features/money/domain/sales_tax_return.dart';
import 'package:flutter_test/flutter_test.dart';

const _rows = [
  SalesTaxReturnRow(
    state: 'NY',
    line: SalesTaxLine.taxable,
    baseCents: 10000,
    taxCents: 850,
    invoiceCount: 1,
  ),
  SalesTaxReturnRow(
    state: 'NY',
    line: SalesTaxLine.tax,
    level: 'city',
    name: 'New York City',
    percent: 4.5,
    baseCents: 10000,
    taxCents: 450,
    invoiceCount: 1,
  ),
  SalesTaxReturnRow(
    state: 'NY',
    line: SalesTaxLine.outside,
    baseCents: 20000,
    taxCents: 0,
    invoiceCount: 1,
  ),
];

void main() {
  final start = DateTime(2026, 9);
  final end = DateTime(2026, 9, 30);

  test('a row of the server function decodes; an unknown kind is skipped', () {
    final row = SalesTaxReturnRow.fromJson({
      'state': 'NY',
      'kind': 'tax',
      'level': 'city',
      'name': 'New York City',
      'percent': 4.5,
      'base_cents': 10000,
      'tax_cents': 450,
      'invoice_count': 1,
    })!;
    expect(
      (row.line, row.name, row.taxCents),
      (SalesTaxLine.tax, 'New York City', 450),
    );
    expect(
      SalesTaxReturnRow.fromJson({'state': 'NY', 'kind': 'from_the_future'}),
      isNull,
    );
  });

  test(
    'the worksheet: a header and a row per line, dots on numbers, text quoted',
    () {
      final lines = salesTaxWorksheetCsv(
        _rows,
        start: start,
        end: end,
      ).trim().split('\r\n');
      expect(
        lines.first,
        'period_start,period_end,state,line,level,jurisdiction,rate_percent,sales,tax,invoices',
      );
      expect(
        lines,
        contains('2026-09-01,2026-09-30,"NY",taxable,,,,100.00,8.50,1'),
      );
      expect(
        lines,
        contains(
          '2026-09-01,2026-09-30,"NY",tax,"city","New York City",4.5,100.00,4.50,1',
        ),
      );
      expect(
        lines,
        contains('2026-09-01,2026-09-30,"NY",outside,,,,200.00,0.00,1'),
      );
    },
  );

  test('a currency without minor units is written whole', () {
    final csv = salesTaxWorksheetCsv(
      _rows.sublist(2),
      start: start,
      end: end,
      currency: 'JPY',
    );
    expect(csv, contains(',20000,0,1'));
  });

  test('the demo states nothing unless a test seeds it', () async {
    final fake = FakeSalesTaxRepository();
    expect(await fake.fetchReturn('w', start: start, end: end), isEmpty);
    fake.rows.addAll(_rows);
    expect(await fake.fetchReturn('w', start: start, end: end), hasLength(3));
  });
}
