// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the SAF-T of a local book: GeneralLedgerEntries are the book's own
// postings, every journal the engine booked, on its accounts; the totals the
// section states are the sums of its lines, every transaction balances, and
// the header says what the section is. Expectations by hand.
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/posting_rules.dart';
import 'package:deskilo/features/money/domain/saf_t.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/seeded_export_year.dart';

BookAccount _account(String code, AccountType type) => BookAccount(
  id: 'acc-$code',
  workspaceId: 'ws',
  issuerSiteId: 'site',
  code: code,
  name: code,
  type: type,
  isPosting: true,
  origin: AccountOrigin.manual,
  revision: 1,
);

BookMapping _map(BookRole role, String code) => BookMapping(
  id: role.wire,
  workspaceId: 'ws',
  issuerSiteId: 'site',
  role: role,
  accountId: 'acc-$code',
  effectiveFrom: DateTime(2020),
  revision: 1,
);

void main() {
  final postings = postingsOf(
    invoices: SeededExportYear.invoices,
    matches: SeededExportYear.matches,
    book: PostingBook(
      accounts: [
        _account('411000', AccountType.asset),
        _account('512000', AccountType.asset),
        _account('706000', AccountType.income),
        _account('445710', AccountType.liability),
        _account('654000', AccountType.expense),
      ],
      mappings: [
        _map(BookRole.customers, '411000'),
        _map(BookRole.bank, '512000'),
        _map(BookRole.revenue, '706000'),
        _map(BookRole.vatOutput, '445710'),
        _map(BookRole.writeOff, '654000'),
      ],
      issuerSiteId: 'site',
    ),
    groupOf: (InvoiceVatTotal _) => '',
  ).postings;
  final doc = XmlDocument.parse(
    buildSafTFile(
      invoices: SeededExportYear.invoices,
      matches: SeededExportYear.matches,
      company: seededCompany,
      currency: 'EUR',
      softwareVersion: '1',
      createdAt: DateTime(2027, 1, 5),
      lineText: (l) => l.label,
      bookPostings: postings,
    ),
  );
  final ledger = doc.findAllElements('GeneralLedgerEntries').single;
  int cents(XmlElement e, String tag) =>
      (double.parse(e.findElements(tag).single.innerText) * 100).round();

  test('every journal the book booked, one transaction per posting', () {
    expect(
      ledger
          .findElements('Journal')
          .map((j) => j.findElements('JournalID').single.innerText),
      ['VE', 'BQ', 'OD'],
    );
    expect(ledger.findAllElements('Transaction'), hasLength(postings.length));
    expect(
      ledger.findElements('NumberOfEntries').single.innerText,
      '${postings.length}',
    );
  });

  test('the totals are the sums of the lines and every transaction '
      'balances', () {
    var debit = 0;
    var credit = 0;
    for (final t in ledger.findAllElements('Transaction')) {
      final d = t
          .findAllElements('DebitAmount')
          .fold<int>(
            0,
            (s, e) => s + (double.parse(e.innerText) * 100).round(),
          );
      final c = t
          .findAllElements('CreditAmount')
          .fold<int>(
            0,
            (s, e) => s + (double.parse(e.innerText) * 100).round(),
          );
      expect(d, c, reason: t.findElements('TransactionID').single.innerText);
      debit += d;
      credit += c;
    }
    expect(cents(ledger, 'TotalDebit'), debit);
    expect(cents(ledger, 'TotalCredit'), credit);
  });

  test('the lines are on the book\'s accounts, and the header says what the '
      'section is', () {
    expect(
      ledger.findAllElements('AccountID').map((e) => e.innerText).toSet(),
      {'411000', '512000', '706000', '445710', '654000'},
    );
    expect(
      doc.findAllElements('HeaderComment').single.innerText,
      contains('postings of the local book'),
    );
  });
}
