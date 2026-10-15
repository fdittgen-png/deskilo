// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 fix 7 — a refunded credit note is money OUT. FEC and DATEV book it
// (customers debited, bank credited), Sage as a payment (SP) and not a
// receipt (SR), SAF-T's ledger the same way round; and Sage carries the
// payments an invoice netted.
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/saf_t.dart';
import 'package:deskilo/features/money/domain/sage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

Map<String, InvoiceMatch> _matches({String resolution = 'refunded'}) => {
  ...SeededExportYear.matches,
  SeededExportYear.creditNote.id: InvoiceMatch(
    invoiceId: SeededExportYear.creditNote.id,
    paidCents: 5000,
    resolution: resolution,
    matchedAt: DateTime(2026, 6, 10),
  ),
};

int _cents(String s) => (double.parse(s.replaceAll(',', '.')) * 100).round();

void main() {
  test('FEC: the refund is customers debited, bank credited, lettered', () {
    final lines = buildFecFile(
      invoices: SeededExportYear.invoices,
      matches: _matches(),
      company: seededCompany,
      accounts: const FecAccounts(),
      lineText: (l) => l.label,
      ledger: SeededExportYear.ledger,
    ).split('\r\n');
    final head = lines.first.split('\t');
    final rows = [
      for (final l in lines.skip(1)) Map.fromIterables(head, l.split('\t')),
    ];
    final refund = rows.where((r) => r['EcritureNum'] == 'BQ-CN-1-R').toList();
    expect(refund, hasLength(2));
    final byAccount = {for (final r in refund) r['CompteNum']!: r};
    expect(_cents(byAccount['411000']!['Debit']!), 5000);
    expect(_cents(byAccount['512000']!['Credit']!), 5000);
    expect(byAccount['411000']!['EcritureLet'], 'INV-2');
    expect(byAccount['411000']!['EcritureDate'], '20260610');
    final debit = rows.fold(0, (s, r) => s + _cents(r['Debit']!));
    final credit = rows.fold(0, (s, r) => s + _cents(r['Credit']!));
    expect(debit, credit);
  });

  test('FEC: no refund row without a refunded match', () {
    final file = buildFecFile(
      invoices: SeededExportYear.invoices,
      matches: SeededExportYear.matches,
      company: seededCompany,
      accounts: const FecAccounts(),
      lineText: (l) => l.label,
      ledger: SeededExportYear.ledger,
    );
    expect(file, isNot(contains('BQ-CN-1-R')));
  });

  test('DATEV: the refund debits the customers and credits the bank', () {
    const accounts = DatevAccounts();
    final rows = buildDatevFile(
      invoices: SeededExportYear.invoices,
      matches: _matches(),
      accounts: accounts,
      from: DateTime(2026),
      to: DateTime(2026, 12, 31),
      generatedAt: DateTime(2027, 1, 5),
      consultantNumber: '1001',
      clientNumber: '20002',
      ledger: SeededExportYear.ledger,
    ).split('\r\n').where((l) => l.contains('Erstattung CN-1')).toList();
    expect(rows, hasLength(1));
    final f = rows.single.split(';');
    expect(f[0], '50,00');
    expect(f[1], '"S"');
    expect(f[6], accounts.customers);
    expect(f[7], accounts.bank);
    expect(f[9], '1006');
  });

  String sage(Map<String, InvoiceMatch> matches) => buildSageFile(
    invoices: SeededExportYear.invoices,
    matches: matches,
    accounts: const SageAccounts(),
    customerRef: (_) => 'C1',
  );

  test('Sage: the refund is a payment (SP), not a receipt (SR)', () {
    final rows = sage(_matches()).split('\r\n');
    final cn = rows.where((l) => l.contains('CN-1')).toList();
    expect(cn.where((l) => l.startsWith('SC,')), isNotEmpty);
    final refund = cn.where((l) => l.startsWith('SP,')).toList();
    expect(refund, hasLength(1));
    expect(refund.single, contains('50.00'));
    expect(cn.where((l) => l.startsWith('SR,')), isEmpty);
  });

  test('Sage: the payment an invoice netted is a receipt on its date', () {
    final rows = sage(SeededExportYear.matches)
        .split('\r\n')
        .where((l) => l.startsWith('SR,') && l.contains('INV-1'))
        .toList();
    // The netted 40.00 on the invoice date, then the 155.50 settlement.
    expect(rows, hasLength(2));
    expect(rows.first, contains('05/03/2026'));
    expect(rows.first, contains('40.00'));
    expect(rows.last, contains('155.50'));
  });

  test('SAF-T ledger: the refund clears the receivable against the bank', () {
    final xml = buildSafTFile(
      invoices: SeededExportYear.invoices,
      matches: _matches(),
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
    final start = xml.indexOf('<TransactionID>CN-1-P</TransactionID>');
    expect(start, greaterThan(0));
    final t = xml.substring(start, xml.indexOf('</Transaction>', start));
    expect(
      RegExp(
        '<DebitLine>.*?<AccountID>411</AccountID>',
        dotAll: true,
      ).hasMatch(t),
      isTrue,
    );
    expect(
      RegExp(
        '<CreditLine>.*?<AccountID>512</AccountID>',
        dotAll: true,
      ).hasMatch(t),
      isTrue,
    );
  });
}
