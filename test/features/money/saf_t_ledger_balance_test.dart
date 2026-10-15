// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 fix 3 — the SAF-T postings of a credit note balance (they used to
// emit a zero credit to the customers and a negative revenue credit with no
// VAT line), and the cash an invoice netted is posted.
import 'package:deskilo/features/money/domain/saf_t.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

String _build() => buildSafTFile(
  invoices: SeededExportYear.invoices,
  matches: SeededExportYear.matches,
  company: seededCompany,
  currency: 'EUR',
  softwareVersion: '1',
  createdAt: DateTime(2027, 1, 5),
  lineText: (l) => l.label,
  ledgerAccounts: const SafTLedgerAccounts(
    customers: '411',
    revenue: '706',
    bank: '512',
    vat: '4457',
  ),
);

int _sum(String xml, String tag) =>
    RegExp('<$tag>([^<]*)</$tag>')
        .allMatches(xml)
        .fold(0, (s, m) => s + (double.parse(m.group(1)!) * 100).round());

String _transaction(String xml, String id) {
  final start = xml.indexOf('<TransactionID>$id</TransactionID>');
  expect(start, greaterThan(0), reason: id);
  return xml.substring(start, xml.indexOf('</Transaction>', start));
}

void main() {
  test('every transaction balances and the header totals are their sums', () {
    final xml = _build();
    final gl = xml.substring(
      xml.indexOf('<GeneralLedgerEntries>'),
      xml.indexOf('</GeneralLedgerEntries>'),
    );
    expect(_sum(gl, 'DebitAmount'), _sum(gl, 'CreditAmount'));
    final header = RegExp('<TotalDebit>([^<]*)</TotalDebit>').firstMatch(gl)!;
    expect(
      (double.parse(header.group(1)!) * 100).round(),
      _sum(gl, 'DebitAmount'),
    );
    for (final id in ['INV-1', 'INV-1-C1', 'CN-1', 'INV-3-P']) {
      final t = _transaction(gl, id);
      expect(_sum(t, 'DebitAmount'), _sum(t, 'CreditAmount'), reason: id);
    }
  });

  test('the credit note reverses the sale: revenue and VAT debited', () {
    final t = _transaction(_build(), 'CN-1');
    expect(t, contains('<DebitAmount>41.67</DebitAmount>'));
    expect(t, contains('<DebitAmount>8.33</DebitAmount>'));
    expect(t, contains('<CreditAmount>50.00</CreditAmount>'));
  });

  test('the cash the invoice netted is a receipt, the expense is not', () {
    final xml = _build();
    final t = _transaction(xml, 'INV-1-C1');
    expect(t, contains('<DebitAmount>40.00</DebitAmount>'));
    expect(xml, isNot(contains('INV-1-C2')));
  });
}
