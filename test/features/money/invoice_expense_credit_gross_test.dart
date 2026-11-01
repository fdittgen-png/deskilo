// SPDX-License-Identifier: AGPL-3.0-or-later
//
// An expense credit that offsets a member's settlement is a negative line on
// the invoice, never a reduction of what was sold: the gross charged and the
// tax it contains stay as issued, the credit is no cash received, and the
// accountant's files book the sale at its gross and its tax.
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/invoice_line_cash.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

int _cents(String s) => (double.parse(s.replaceAll(',', '.')) * 100).round();

void main() {
  final invoice = SeededExportYear.inv1;

  test('gross, tax and net are those of the sale; the expense credit only '
      'lowers the balance due', () {
    expect(invoice.lines.where((l) => l.kind == 'expense'), hasLength(1));
    expect(invoice.chargesCents, 22550, reason: '12000 + 10550 sold');
    expect(invoice.vatCents, 2550, reason: '2000 + 550 contained');
    expect(invoice.netCents, 20000);
    expect(invoice.totalCents, 15550, reason: 'sold 22550 - 4000 - 3000');
  });

  test('the expense credit is not money received', () {
    final byKind = {for (final l in invoice.lines) l.kind: l.isMoneyIn};
    expect(byKind['expense'], isFalse);
    expect(byKind['payment'], isTrue);
  });

  test(
    'FEC: the sale books its full tax and revenue, the credit books none',
    () {
      final lines = buildFecFile(
        FecRequest(
          invoices: SeededExportYear.invoices,
          matches: SeededExportYear.matches,
          company: seededCompany,
          accounts: const FecAccounts(),
          lineText: (l) => l.label,
          ledger: SeededExportYear.ledger,
        ),
      ).split('\r\n');
      final head = lines.first.split('\t');
      final rows = [
        for (final l in lines.skip(1).where((l) => l.isNotEmpty))
          Map.fromIterables(head, l.split('\t')),
      ];
      final sale = rows.where((r) => r['PieceRef'] == 'INV-1').toList();
      final vatCredit = sale
          .where((r) => r['CompteNum']!.startsWith('4457'))
          .fold(0, (s, r) => s + _cents(r['Credit']!));
      final revenue = sale
          .where((r) => r['CompteNum']!.startsWith('7'))
          .fold(0, (s, r) => s + _cents(r['Credit']!));
      expect(vatCredit, invoice.vatCents);
      expect(revenue, invoice.netCents);
    },
  );
}
