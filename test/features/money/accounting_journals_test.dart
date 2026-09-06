// SPDX-License-Identifier: 0BSD
//
// #936 — the exports carry the purchases side, book credit notes, and
// mark a development workspace's books.
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/invoice_line_text.dart';
import 'package:flutter_test/flutter_test.dart';

const _company = InvoiceParty(
  name: 'pezenas1', street: '2 Place du Marché', city: 'Pézenas',
  postalCode: '34120', country: 'FR', legalId: '812 345 678',
  vatRegime: 'not_subject',
);

Invoice _invoice({String number = 'INV-2026-0001', int total = 25000, String replaces = ''}) =>
    Invoice(
      id: 'inv-$number', workspaceId: 'ws-1', memberId: 'member-1', number: number,
      issuedAt: DateTime(2026, 7, 2), period: '2026-06', title: '2026-06',
      lines: [InvoiceLine(kind: 'subscription', label: '100', amountCents: total)],
      totalCents: total, currency: 'EUR', memberName: 'Ana Martin',
      memberAddress: '1 Rue du Test', workspaceName: 'pezenas1',
      workspaceAddress: '2 Place du Marché', issuerName: 'Flo', signature: 'f' * 64,
      sellerParty: _company, replacesNumber: replaces,
    );

final _reimbursement = LedgerEntry(
  id: 'le-1', memberId: 'member-1', kind: LedgerKind.credit,
  category: LedgerCategory.expense, amountCents: 2990, description: 'internet',
  period: '2026-06', createdAt: DateTime(2026, 6, 15),
);

final _rent = ExpenseRepartition(
  id: 'rep-1', title: 'Loyer juin', amountCents: 60000,
  method: RepartitionMethod.subscription, period: '2026-06',
  shares: const [], status: 'confirmed', createdAt: DateTime(2026, 6, 30),
);

List<Map<String, String>> _rows(String file) {
  final lines = file.split('\r\n').where((l) => l.isNotEmpty).toList();
  final head = lines.first.split('\t');
  return [
    for (final l in lines.skip(1))
      Map.fromIterables(head, l.split('\t')),
  ];
}

void main() {
  group('FEC', () {
    test('a credit note is booked as a sale reversed, lettered with the '
        'invoice it corrects — it used to be absent', () {
      final file = buildFecFile(
        invoices: [_invoice(), _invoice(number: 'CN-2026-0001', total: -25000, replaces: 'INV-2026-0001')],
        matches: const {}, company: _company, accounts: const FecAccounts(),
        lineText: (line) => invoiceLineText(null, line),
      );
      final cn = _rows(file).where((r) => r['PieceRef'] == 'CN-2026-0001').toList();
      num money(String? s) => num.parse((s ?? '0').replaceAll(',', '.'));
      final revenueDebit = cn.where((r) => r['CompteNum'] == '706000').fold<num>(0, (t, r) => t + money(r['Debit']));
      final customerCredit = cn.where((r) => r['CompteNum'] == '411000').fold<num>(0, (t, r) => t + money(r['Credit']));
      expect(revenueDebit, 250, reason: cn.toString());
      expect(customerCredit, 250, reason: cn.toString());
      expect(cn.where((r) => r['CompteNum'] == '445710'), isEmpty, reason: 'not subject to VAT');
      expect(cn.map((r) => r['EcritureLet']).toSet(), {'INV-2026-0001'}, reason: 'lettered with the invoice it corrects');
      expect(cn.map((r) => r['EcritureNum']).toSet(), {'VE-CN-2026-0001'});
    });

    test('a reimbursed expense lands in the purchases journal, balanced, '
        'expenses against the member\'s customer account', () {
      final file = buildFecFile(
        invoices: [_invoice()], matches: const {}, company: _company,
        accounts: const FecAccounts(), lineText: (line) => invoiceLineText(null, line),
        ledger: [_reimbursement], memberNames: const {'member-1': 'Ana Martin'},
      );
      final ha = _rows(file).where((r) => r['JournalCode'] == 'HA').toList();
      expect(ha, hasLength(2));
      expect(ha.map((r) => r['EcritureNum']).toSet(), {'HA-le-1'});
      expect(ha.singleWhere((r) => r['CompteNum'] == '606000')['Debit'], '29,90');
      final cust = ha.singleWhere((r) => r['CompteNum'] == '411000');
      expect((cust['Credit'], cust['CompAuxLib']), ('29,90', 'Ana Martin'));
    });

    test('a shared cost the workspace paid is the expense itself, from the bank', () {
      final file = buildFecFile(
        invoices: [_invoice()], matches: const {}, company: _company,
        accounts: const FecAccounts(), lineText: (line) => invoiceLineText(null, line),
        repartitions: [_rent],
      );
      final ha = _rows(file).where((r) => r['JournalCode'] == 'HA').toList();
      expect(ha.singleWhere((r) => r['CompteNum'] == '606000')['Debit'], '600,00');
      expect(ha.singleWhere((r) => r['CompteNum'] == '512000')['Credit'], '600,00');
    });

    test('an association that does not charge VAT books no VAT row', () {
      final file = buildFecFile(
        invoices: [_invoice(), _invoice(number: 'CN-2026-0001', total: -1000)],
        matches: const {}, company: _company, accounts: const FecAccounts(),
        lineText: (line) => invoiceLineText(null, line),
      );
      expect(_rows(file).where((r) => r['CompteNum'] == '445710'), isEmpty);
    });

    test('a development workspace\'s file says so in its name', () {
      expect(fecFileName('812 345 678', DateTime(2026, 12, 31), development: true),
          'DEV-812345678FEC20261231.txt');
      expect(fecFileName('812 345 678', DateTime(2026, 12, 31)),
          '812345678FEC20261231.txt');
    });
  });

  group('DATEV', () {
    String build({List<Invoice>? invoices, bool development = false}) => buildDatevFile(
          invoices: invoices ?? [_invoice()], matches: const {},
          accounts: const DatevAccounts(), from: DateTime(2026, 1, 1), to: DateTime(2026, 12, 31),
          generatedAt: DateTime(2026, 9, 6, 10), consultantNumber: '1', clientNumber: '2',
          ledger: [_reimbursement], repartitions: [_rent], development: development,
        );

    test('a credit note swaps the accounts and stays positive', () {
      final rows = build(invoices: [_invoice(number: 'CN-1', total: -25000)]).split('\r\n');
      final cn = rows.firstWhere((r) => r.contains('"CN-1"'));
      expect(cn, startsWith('250,00;"S"'));
      expect(cn, contains(';8400;10000;'));
    });

    test('the purchases side is there: reimbursement against the customer, '
        'shared cost against the bank', () {
      final rows = build().split('\r\n');
      expect(rows.where((r) => r.contains('"le-1"')).single, contains(';4900;10000;'));
      expect(rows.where((r) => r.contains('"rep-1"')).single, contains(';4900;1200;'));
    });

    test('a development workspace\'s batch is named as such', () {
      expect(build(development: true).split('\r\n').first, contains('ENTWICKLUNG DesKilo'));
      expect(build().split('\r\n').first, isNot(contains('ENTWICKLUNG')));
    });
  });
}
