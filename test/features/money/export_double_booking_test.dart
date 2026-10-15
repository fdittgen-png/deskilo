// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 fix 1 — a ledger expense credit netted on an invoice is booked ONCE
// (the purchases journal). It used to be booked a second time as money in
// on the bank, and a goodwill adjustment credit as cash too.
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

int _cents(String s) => (double.parse(s.replaceAll(',', '.')) * 100).round();

void main() {
  test('FEC: the netted expense never reaches the bank, the payment does', () {
    final file = buildFecFile(
      invoices: SeededExportYear.invoices,
      matches: SeededExportYear.matches,
      company: seededCompany,
      accounts: const FecAccounts(),
      lineText: (l) => l.label,
      ledger: SeededExportYear.ledger,
    );
    final lines = file.split('\r\n');
    final head = lines.first.split('\t');
    final rows = [
      for (final l in lines.skip(1)) Map.fromIterables(head, l.split('\t')),
    ];
    expect(
      rows.where((r) => r['EcritureLib']!.contains('Taxi refund')),
      isEmpty,
    );
    final bankDebit = rows
        .where((r) => r['CompteNum'] == '512000')
        .fold(0, (s, r) => s + _cents(r['Debit']!));
    // 40.00 netted payment + 155.50 + 120.00 + 60.00 settlements.
    expect(bankDebit, 4000 + 15550 + 12000 + 6000);
  });

  test('DATEV: the netted expense is no Zahlung', () {
    final file = buildDatevFile(
      invoices: SeededExportYear.invoices,
      matches: SeededExportYear.matches,
      accounts: const DatevAccounts(),
      from: DateTime(2026),
      to: DateTime(2026, 12, 31),
      generatedAt: DateTime(2027, 1, 5),
      consultantNumber: '1001',
      clientNumber: '20002',
      ledger: SeededExportYear.ledger,
    );
    final zahlung = file
        .split('\r\n')
        .where((l) => l.contains('Zahlung INV-1'))
        .map((l) => l.split(';').first)
        .toList();
    // The netted payment, then the settlement; never the 30,00 expense.
    expect(zahlung, ['40,00', '155,50']);
  });
}
