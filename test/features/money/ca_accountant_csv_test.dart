// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is that the CSV states GST and QST apart only when an invoice does
//
// #2361 — a Quebec invoice of CAD 1 000.00: the accountant CSV shows the
// GST (50.00) and the QST (99.75) in their own columns; a file without
// such an invoice keeps the columns it always had.
import 'package:deskilo/features/money/domain/accountant_csv.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_components.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(
  String number,
  String currency,
  double percent,
  int gross,
  int net,
  String country,
) => Invoice(
  id: number,
  workspaceId: 'w',
  memberId: 'm',
  number: number,
  issuedAt: DateTime(2026, 9, 30),
  title: '2026-09',
  lines: [InvoiceLine(label: 'Desk', amountCents: gross, vatPercent: percent)],
  totalCents: gross,
  currency: currency,
  memberName: 'Ana',
  memberAddress: '',
  workspaceName: 'W',
  workspaceAddress: '',
  issuerName: 'I',
  signature: 's',
  vatTotals: [
    InvoiceVatTotal(
      percent: percent,
      category: 'S',
      grossCents: gross,
      netCents: net,
      vatCents: gross - net,
      components: vatComponentsOf(country, percent, net, gross - net),
    ),
  ],
);

String _csv(List<Invoice> invoices) => buildAccountantCsv(
  invoices: invoices,
  matches: const {},
  generatedAt: DateTime(2026, 10),
  workspaceName: 'W',
);

void main() {
  test(
    'a Quebec invoice: GST and QST in their own columns, rates as taxes',
    () {
      final lines = _csv([_invoice('F-1', 'CAD', 14.975, 114975, 100000, 'CA')])
          .trim()
          .split('\n');
      final header = lines.firstWhere((l) => l.startsWith('invoice_number'));
      expect(header, endsWith(',vat_gst_hst,vat_qst,vat_pst'));
      final row = lines.last;
      expect(row, endsWith(',50.00,99.75,0.00'));
      expect(row, contains('GST 5% + QST 9.975%'));
    },
  );

  test('without such an invoice the file is exactly what it was', () {
    final csv = _csv([_invoice('F-2', 'EUR', 20, 12000, 10000, 'FR')]);
    final header = csv
        .split('\n')
        .firstWhere((l) => l.startsWith('invoice_number'));
    expect(header, accountantCsvColumns.join(','));
    expect(csv, isNot(contains('vat_qst')));
    expect(csv, contains('20.00%'));
  });
}
