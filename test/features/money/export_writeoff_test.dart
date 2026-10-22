// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 defect 7a -- what the owner gave up of an invoice is booked: the
// unpaid rest leaves the receivable for the loss account on the write-off
// day, lettered with the invoice so the group closes, at the gross amount
// (the VAT regularisation is the accountant's). Seeded year: INV-3 of
// 100.00 was paid 60.00 and the remaining 40.00 written off on 25 May.
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/saf_t.dart';
import 'package:deskilo/features/money/domain/sage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

int _cents(String s) => (double.parse(s.replaceAll(',', '.')) * 100).round();

List<Map<String, String>> _fec({Map<String, InvoiceMatch>? matches}) {
  final file = buildFecFile(FecRequest(
    invoices: SeededExportYear.invoices,
    matches: matches ?? SeededExportYear.matches,
    company: seededCompany,
    accounts: const FecAccounts(),
    lineText: (l) => l.label,
    ledger: SeededExportYear.ledger,
  ));
  final lines = file.split('\r\n');
  final head = lines.first.split('\t');
  return [
    for (final l in lines.skip(1))
      if (l.isNotEmpty) Map.fromIterables(head, l.split('\t')),
  ];
}

void main() {
  test('FEC: the written-off rest is a loss on the write-off day', () {
    final rows = _fec().where((r) => r['EcritureNum'] == 'OD-INV-3-W').toList();
    expect(rows, hasLength(2));
    final loss = rows.singleWhere((r) => r['CompteNum'] == '654000');
    final customer = rows.singleWhere((r) => r['CompteNum'] == '411000');
    expect(_cents(loss['Debit']!), 4000);
    expect(_cents(customer['Credit']!), 4000);
    expect(loss['EcritureDate'], '20260525');
    expect(loss['JournalCode'], 'OD');
    expect(loss['EcritureLib'], 'Créance irrécouvrable INV-3');
  });

  test('FEC: INV-3 is lettered whole — what was billed equals what was paid plus given up', () {
    final group = _fec().where((r) => r['EcritureLet'] == 'INV-3').toList();
    final debit = group.fold(0, (s, r) => s + (r['CompteNum'] == '411000' ? _cents(r['Debit']!) : 0));
    final credit = group.fold(0, (s, r) => s + (r['CompteNum'] == '411000' ? _cents(r['Credit']!) : 0));
    expect(debit, 10000);
    expect(credit, 6000 + 4000);
    // every lettered row carries the lettering date
    expect(group.every((r) => r['DateLet']!.isNotEmpty), isTrue);
  });

  test('FEC: every entry stays balanced, and an invoice that was not written off books no loss', () {
    final rows = _fec();
    final byEntry = <String, int>{};
    for (final r in rows) {
      byEntry.update(r['EcritureNum']!, (v) => v + _cents(r['Debit']!) - _cents(r['Credit']!),
          ifAbsent: () => _cents(r['Debit']!) - _cents(r['Credit']!));
    }
    expect(byEntry.entries.where((e) => e.value != 0), isEmpty);
    expect(rows.where((r) => r['CompteNum'] == '654000'), hasLength(1));
  });

  test('FEC: a write-off still awaiting validation books nothing', () {
    final matches = {
      ...SeededExportYear.matches,
      SeededExportYear.inv3.id: InvoiceMatch(
        invoiceId: SeededExportYear.inv3.id,
        paidCents: 6000,
        resolution: 'writeoff',
        matchedAt: DateTime(2026, 5, 20),
        writeoffAt: DateTime(2026, 5, 25),
        status: 'pending',
      ),
    };
    expect(_fec(matches: matches).where((r) => r['CompteNum'] == '654000'), isEmpty);
  });

  group('DATEV', () {
    List<String> datev({Map<String, InvoiceMatch>? matches}) => buildDatevFile(DatevRequest(
      invoices: SeededExportYear.invoices,
      matches: matches ?? SeededExportYear.matches,
      accounts: const DatevAccounts(),
      from: DateTime(2026),
      to: DateTime(2026, 12, 31),
      generatedAt: DateTime(2027, 1, 5),
      consultantNumber: '1001',
      clientNumber: '20002',
      ledger: SeededExportYear.ledger,
    )).split('\r\n');

    test('the written-off rest is a Forderungsverlust on the write-off day', () {
      final rows = datev().where((l) => l.contains('Forderungsverlust INV-3')).toList();
      expect(rows, hasLength(1));
      final f = rows.single.split(';');
      expect(f[0], '40,00');
      expect(f[1], '"S"');
      expect(f[6], '2400');
      expect(f[7], '10000');
      expect(f[9], '2505');
    });

    test('an invoice that was not written off books no loss, nor does a pending one', () {
      expect(datev().where((l) => l.contains('Forderungsverlust')), hasLength(1));
      final pending = {
        ...SeededExportYear.matches,
        SeededExportYear.inv3.id: InvoiceMatch(
          invoiceId: SeededExportYear.inv3.id,
          paidCents: 6000,
          resolution: 'writeoff',
          matchedAt: DateTime(2026, 5, 20),
          writeoffAt: DateTime(2026, 5, 25),
          status: 'pending',
        ),
      };
      expect(datev(matches: pending).where((l) => l.contains('Forderungsverlust')), isEmpty);
    });
  });

  group('Sage', () {
    List<String> sage({Map<String, InvoiceMatch>? matches}) => buildSageFile(
      invoices: SeededExportYear.invoices,
      matches: matches ?? SeededExportYear.matches,
      accounts: const SageAccounts(),
      customerRef: (i) => i.memberId,
    ).split('\r\n');

    test('the written-off rest is a sales credit to the bad-debt nominal, without tax', () {
      final rows = sage().where((l) => l.contains('Write-off INV-3')).toList();
      expect(rows, hasLength(1));
      final f = rows.single.split(',');
      expect(f[0], 'SC');
      expect(f[2], '8100');
      expect(f[4], '25/05/2026');
      expect(f[7], '40.00');
      expect(f[8], const SageAccounts().noTax);
      expect(f[9], '0.00');
    });

    test('nothing is written off for an invoice that was not, nor for a pending match', () {
      expect(sage().where((l) => l.contains('Write-off')), hasLength(1));
      final pending = {
        ...SeededExportYear.matches,
        SeededExportYear.inv3.id: InvoiceMatch(
          invoiceId: SeededExportYear.inv3.id,
          paidCents: 6000,
          resolution: 'writeoff',
          matchedAt: DateTime(2026, 5, 20),
          writeoffAt: DateTime(2026, 5, 25),
          status: 'pending',
        ),
      };
      expect(sage(matches: pending).where((l) => l.contains('Write-off')), isEmpty);
    });
  });

  group('SAF-T', () {
    String saft({String writeOff = '654', Map<String, InvoiceMatch>? matches}) => buildSafTFile(SafTRequest(
      invoices: SeededExportYear.invoices,
      matches: matches ?? SeededExportYear.matches,
      company: seededCompany,
      currency: 'EUR',
      softwareVersion: '1',
      createdAt: DateTime(2027, 1, 5),
      lineText: (l) => l.label,
      ledgerAccounts: SafTLedgerAccounts(
        customers: '411',
        revenue: '706',
        bank: '512',
        vat: '4457',
        writeOff: writeOff,
      ),
    ));

    test('the written-off rest is a balanced transaction in the sales journal', () {
      final xml = saft();
      final start = xml.indexOf('<TransactionID>INV-3-W</TransactionID>');
      expect(start, greaterThan(0));
      final t = xml.substring(start, xml.indexOf('</Transaction>', start));
      expect(t, contains('<TransactionDate>2026-05-25</TransactionDate>'));
      expect(t, contains('<AccountID>654</AccountID>'));
      expect(t, contains('<DebitAmount>40.00</DebitAmount>'));
      expect(t, contains('<CreditAmount>40.00</CreditAmount>'));
      // the sales journal carries the adjustment of the receivable
      expect(xml.indexOf('INV-3-W'), greaterThan(xml.indexOf('<JournalID>VE</JournalID>')));
      expect(xml.indexOf('INV-3-W'), lessThan(xml.indexOf('<JournalID>BQ</JournalID>')));
    });

    test('without a mapped loss account nothing is invented', () {
      final xml = saft(writeOff: '');
      expect(xml, isNot(contains('INV-3-W')));
    });

    test('a pending write-off is not posted', () {
      final pending = {
        ...SeededExportYear.matches,
        SeededExportYear.inv3.id: InvoiceMatch(
          invoiceId: SeededExportYear.inv3.id,
          paidCents: 6000,
          resolution: 'writeoff',
          matchedAt: DateTime(2026, 5, 20),
          writeoffAt: DateTime(2026, 5, 25),
          status: 'pending',
        ),
      };
      expect(saft(matches: pending), isNot(contains('INV-3-W')));
    });
  });
}
