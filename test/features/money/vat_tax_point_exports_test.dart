// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2355 — the declaration, the VAT report and the accounting exports read
// ONE tax-point engine, so they agree. The FEC books an invoice's VAT on
// the pending account (44574) until its tax point and moves it to 44571
// on that day, so the collected-VAT account of a month is what the
// month declares; DATEV carries the tax point in field 116 (`Datum
// Zuord. Steuerperiode`). Without the engine's ledger both files book
// every VAT on the issue day, as before.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/money/application/declare_vat.dart';
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_report.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _on(int year, int month, int day) =>
    WorkspaceTime.at(year, month, day, 12).toUtc();

Invoice _invoice(String number, {required DateTime issuedAt, String? period}) =>
    Invoice(
      id: 'id-$number',
      workspaceId: 'ws-1',
      memberId: 'm-1',
      number: number,
      issuedAt: issuedAt,
      period: period,
      title: number,
      lines: const [
        InvoiceLine(label: 'Desk', amountCents: 12000, vatPercent: 20),
      ],
      totalCents: 12000,
      currency: 'EUR',
      memberName: 'Ada',
      memberAddress: '',
      workspaceName: 'Space',
      workspaceAddress: '',
      issuerName: '',
      signature: '',
    );

InvoiceMatch _match(String invoiceId, int cents, DateTime on) => InvoiceMatch(
  invoiceId: invoiceId,
  paidCents: cents,
  resolution: cents == 12000 ? 'exact' : 'under_accepted',
  matchedAt: on,
);

const _company = InvoiceParty(
  name: 'Space SAS',
  country: 'FR',
  legalId: '123456789',
  vatRegime: 'vat_registered',
);

List<Map<String, String>> _fecRows(String file) {
  final lines = file.split('\r\n');
  final header = lines.first.split('\t');
  return [
    for (final line in lines.skip(1))
      {for (final (i, cell) in line.split('\t').indexed) header[i]: cell},
  ];
}

int _cents(String? amount) =>
    (double.parse((amount ?? '0').replaceAll(',', '.')) * 100).round();

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  // A French space on receipts: issued in August, half paid in September,
  // half in October.
  final invoice = _invoice('INV-1', issuedAt: _on(2026, 8, 10));
  final matches = {'id-INV-1': _match('id-INV-1', 12000, _on(2026, 10, 7))};
  final instalments = {
    'id-INV-1': [
      TaxPointPayment(_on(2026, 9, 5), 6000),
      TaxPointPayment(_on(2026, 10, 7), 6000),
    ],
  };
  const basis = VatTaxPointBasis.receipt;
  final ledger = vatTaxPointLedger(
    [invoice],
    matches: matches,
    instalments: instalments,
    basis: basis,
  );

  String fec({List<VatTaxPointAmount>? taxPoints}) => buildFecFile(
    invoices: [invoice],
    matches: matches,
    company: _company,
    accounts: const FecAccounts(),
    lineText: (line) => invoiceLineText(const ReportStrings(), line),
    taxPoints: taxPoints,
  );

  group('the FEC', () {
    test('books the VAT pending at issue and releases each part on its '
        'tax point', () {
      final rows = _fecRows(fec(taxPoints: ledger));
      final sale = rows.where((r) => r['JournalCode'] == 'VE');
      expect(sale.where((r) => r['CompteNum'] == '445710'), isEmpty);
      expect(
        _cents(sale.singleWhere((r) => r['CompteNum'] == '445740')['Credit']),
        2000,
      );
      final od = rows.where((r) => r['JournalCode'] == 'OD').toList();
      final collected = {
        for (final r in od.where((r) => r['CompteNum'] == '445710'))
          r['EcritureDate']: _cents(r['Credit']),
      };
      expect(collected, {'20260905': 1000, '20261007': 1000});
      final pendingDebits = od
          .where((r) => r['CompteNum'] == '445740')
          .fold(0, (s, r) => s + _cents(r['Debit']));
      expect(pendingDebits, 2000, reason: 'paid in full: nothing waits');
    });

    test('an unpaid part stays pending', () {
      final unpaid = vatTaxPointLedger([invoice], basis: basis);
      final rows = _fecRows(fec(taxPoints: unpaid));
      expect(rows.where((r) => r['JournalCode'] == 'OD'), isEmpty);
      expect(rows.where((r) => r['CompteNum'] == '445710'), isEmpty);
    });

    test('without the ledger every VAT is due on the issue day, as before', () {
      final rows = _fecRows(fec());
      expect(rows.where((r) => r['CompteNum'] == '445740'), isEmpty);
      expect(
        _cents(rows.singleWhere((r) => r['CompteNum'] == '445710')['Credit']),
        2000,
      );
    });
  });

  test('the declaration, the VAT report and the FEC agree, month by month', () {
    final rows = _fecRows(fec(taxPoints: ledger));
    for (final month in [8, 9, 10]) {
      final start = DateTime(2026, month);
      final end = DateTime(2026, month + 1, 0);
      final declared = vatDeclarationDraft(
        invoices: [invoice],
        matches: matches,
        instalments: instalments,
        periodStart: start,
        periodEnd: end,
        basis: basis,
      ).totalVatCents;
      final reported = buildVatReport(
        [invoice],
        start: start,
        end: end,
        zeroCategory: 'S',
        matches: matches,
        instalments: instalments,
        basis: basis,
      ).vatCents;
      final prefix = '2026${month.toString().padLeft(2, '0')}';
      final booked = rows
          .where(
            (r) =>
                r['CompteNum'] == '445710' &&
                r['EcritureDate']!.startsWith(prefix),
          )
          .fold(0, (s, r) => s + _cents(r['Credit']) - _cents(r['Debit']));
      expect(
        [declared, reported, booked],
        month == 8 ? [0, 0, 0] : [1000, 1000, 1000],
        reason: 'month $month',
      );
    }
  });

  group('DATEV', () {
    List<List<String>> rowsOf(String file) => [
      for (final l
          in file.substring(1).split('\r\n').where((l) => l.isNotEmpty).skip(2))
        l.split(';'),
    ];
    String datev(List<Invoice> invoices, List<VatTaxPointAmount>? points) =>
        buildDatevFile(
          invoices: invoices,
          matches: const {},
          accounts: const DatevAccounts(),
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 12, 31),
          generatedAt: DateTime(2026, 10, 1, 9),
          consultantNumber: '1234567',
          clientNumber: '54321',
          taxPoints: points,
        );

    test('a subscription invoiced 25 August for September carries '
        'September in field 116', () {
      final september = _invoice(
        'RE-1',
        issuedAt: _on(2026, 8, 25),
        period: '2026-09',
      );
      final points = vatTaxPointLedger([
        september,
      ], basis: const VatTaxPointBasis(VatTaxPointRule.servicePeriod));
      final row = rowsOf(datev([september], points)).single;
      expect(row[9], '2508', reason: 'the Belegdatum stays the document\'s');
      expect(row[115], '30092026');
    });

    test('instalments on a cash basis split the sale per payment day, the '
        'unpaid rest without a tax date', () {
      final points = vatTaxPointLedger(
        [invoice],
        matches: {'id-INV-1': _match('id-INV-1', 6000, _on(2026, 9, 5))},
        instalments: {
          'id-INV-1': [TaxPointPayment(_on(2026, 9, 5), 6000)],
        },
        basis: basis,
      );
      final sale = rowsOf(datev([invoice], points))
          .where((r) => r[13].contains('Rechnung'))
          .toList();
      expect(sale.map((r) => (r[0], r[115])), [
        ('60,00', '05092026'),
        ('60,00', ''),
      ]);
    });

    test('a sale due on its issue day carries no tax date', () {
      final points = vatTaxPointLedger([invoice]);
      expect(rowsOf(datev([invoice], points)).single[115], '');
    });
  });
}
