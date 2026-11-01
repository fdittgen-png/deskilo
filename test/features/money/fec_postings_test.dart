// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the FEC of a local book is the engine's postings over the seeded
// year, on the book's own chart: the 18 columns, entries numbered from the
// document they book, every entry balanced, and a receivable lettered with
// its document only when that document's lines on it balance (INV-3, paid
// in part and written off), with DateLet the day of the last of them, and
// naming its member in the auxiliary columns (#2376).
// Expectations by hand.
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:deskilo/features/money/domain/accounting_target.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/fec_postings.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/posting_rules.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

BookAccount _account(String code, AccountType type) => BookAccount(
  id: 'acc-$code',
  workspaceId: 'ws',
  issuerSiteId: 'site',
  code: code,
  name: 'Compte $code',
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
  final set = postingsOf(
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
  );
  final inv3 = SeededExportYear.invoices.singleWhere(
    (i) => i.number == 'INV-3',
  );
  // Every invoice's member; INV-3's is the one asserted below.
  final parties = {
    for (final i in SeededExportYear.invoices)
      i.id: const PostingParty(kind: 'member', number: 'M-0007', name: 'Ana Lopez'),
  };
  final written = buildFecFromPostings(
    set.postings,
    accountNames: const {'411000': 'Clients', '512000': 'Banques'},
    parties: parties,
  );
  final file = written.file;
  final rows = [
    for (final line in file.split('\r\n').skip(1)) line.split('\t'),
  ];

  test('the header is the 18 columns of the arrêté', () {
    expect(file.split('\r\n').first, fecColumns.join('\t'));
    expect(rows.every((r) => r.length == 18), isTrue);
    expect(set.blockers, isEmpty);
    expect(written.blockers, isEmpty);
  });

  test('entries are numbered from their document and each balances', () {
    final byEntry = <String, int>{};
    for (final r in rows) {
      int cents(String s) => int.parse(s.replaceAll(',', ''));
      byEntry[r[2]] = (byEntry[r[2]] ?? 0) + cents(r[11]) - cents(r[12]);
    }
    expect(byEntry.keys, containsAll(['VE-INV-1', 'BQ-INV-1', 'BQ-INV-1-2']));
    expect(byEntry.values.every((v) => v == 0), isTrue);
  });

  test('the chart names its accounts; an unnamed one shows its code', () {
    final clients = rows.firstWhere((r) => r[4] == '411000');
    expect((clients[0], clients[1], clients[5]), ('VE', 'Ventes', 'Clients'));
    expect(rows.firstWhere((r) => r[4] == '706000')[5], '706000');
  });

  test('a receivable whose document balances is lettered, with DateLet', () {
    final inv3Rows = [
      for (final r in rows)
        if (r[4] == '411000' && r[8] == 'INV-3') r,
    ];
    expect(inv3Rows, isNotEmpty);
    expect(inv3Rows.every((r) => r[13] == 'INV-3'), isTrue);
    expect(inv3Rows.map((r) => r[14]).toSet(), {'20260525'});
    expect(inv3Rows.map((r) => (r[6], r[7])).toSet(), {
      ('411M0007', 'Ana Lopez'),
    }, reason: 'the receivable names its member in the auxiliary account '
        'of the collective: its root and the member number');
    expect(
      rows
          .where((r) => r[8] == 'INV-3' && r[4] != '411000')
          .every((r) => r[6].isEmpty),
      isTrue,
      reason: 'only the third-party account carries the auxiliary',
    );
    final inv2 = [
      for (final r in rows)
        if (r[4] == '411000' && r[8] == 'INV-2') r,
    ];
    expect(
      inv2.every((r) => r[13].isEmpty && r[14].isEmpty),
      isTrue,
      reason: 'INV-2 is still partly open',
    );
  });

  // #2376 — the auxiliary account of a third party.
  test('a client code is the collective root and the number in capitals', () {
    const rule = CustomerIdRule(maxLength: 13, charset: r'[A-Z0-9]+');
    expect(fecAuxAccount('411000', 'M-0007', rule), '411M0007');
    expect(fecAuxAccount('401000', '17', rule), '40117');
    expect(fecAuxAccount('411000', '', rule), isNull);
    expect(fecAuxAccount('411000', '--', rule), isNull);
    expect(fecAuxAccount('411000', 'A' * 14, rule), isNull);
    expect(fecAuxAccount('411000', 'A' * 13, rule), '411${'A' * 13}');
  });

  test('a receivable without a party, or two parties on one code, stop the '
      'file and are named', () {
    final missing = buildFecFromPostings(
      set.postings,
      accountNames: const {},
      parties: {
        for (final MapEntry(:key, :value) in parties.entries)
          if (key != inv3.id) key: value,
      },
    );
    expect(missing.file, isEmpty);
    expect(missing.blockers, [const FecBlocker(FecBlock.partyCode, 'INV-3')]);
    final shared = buildFecFromPostings(
      set.postings,
      accountNames: const {},
      parties: {
        for (final MapEntry(:key, :value) in parties.entries)
          key: key == inv3.id
              ? const PostingParty(kind: 'member', number: 'M 0007', name: 'Bo')
              : value,
      },
    );
    expect(shared.blockers.single.block, FecBlock.partyCode);
  });

  // #2376 — a document in another currency than the book's: the book's
  // currency at the recorded rate, the original in Montantdevise/Idevise.
  test('a CHF entry is written in EUR with its original amount, balanced', () {
    final chf = Posting(
      journal: PostingJournal.sales,
      date: DateTime(2026, 6, 2),
      kind: PostingKind.invoice,
      documentId: 'chf-1',
      documentNumber: 'INV-CHF-1',
      lines: [
        PostingLine(
          role: BookRole.customers,
          accountCode: '411000',
          debit: AccountingAmount('CHF', 10001),
          credit: AccountingAmount('CHF', 0),
        ),
        PostingLine(
          role: BookRole.revenue,
          accountCode: '706000',
          debit: AccountingAmount('CHF', 0),
          credit: AccountingAmount('CHF', 8334),
        ),
        PostingLine(
          role: BookRole.vatOutput,
          accountCode: '445710',
          debit: AccountingAmount('CHF', 0),
          credit: AccountingAmount('CHF', 1667),
        ),
      ],
    );
    const party = {'chf-1': PostingParty(kind: 'member', number: 'M-9', name: 'Zoé')};
    final rate = FxRate(
      base: 'CHF',
      quote: 'EUR',
      rate: ExactDecimal.parse('1.0657'),
      source: 'ECB reference',
      date: DateTime(2026, 6, 2),
      version: '2026-06-02',
    );
    final refused = buildFecFromPostings(
      [chf],
      accountNames: const {},
      parties: party,
      functionalCurrency: 'EUR',
    );
    expect(refused.blockers, [
      const FecBlocker(FecBlock.missingRate, 'INV-CHF-1 (CHF)'),
    ]);
    final fec = buildFecFromPostings(
      [chf],
      accountNames: const {},
      parties: party,
      functionalCurrency: 'EUR',
      rates: {'chf-1': rate},
    );
    final lines = [
      for (final l in fec.file.split('\r\n').skip(1)) l.split('\t'),
    ];
    int cents(String s) => int.parse(s.replaceAll(',', ''));
    expect(lines.map((r) => (r[16], r[17])), [
      ('100,01', 'CHF'),
      ('83,34', 'CHF'),
      ('16,67', 'CHF'),
    ]);
    // 100.01 × 1.0657 = 106.58, but 83.34 → 88.82 and 16.67 → 17.77 credit
    // 106.59: the debit side is one cent short and its largest line takes it.
    expect(lines.map((r) => (cents(r[11]), cents(r[12]))), [
      (10659, 0),
      (0, 8882),
      (0, 1777),
    ]);
    expect(
      lines.fold<int>(0, (s, r) => s + cents(r[11]) - cents(r[12])),
      0,
    );
  });

  // #3184 — the euro file is not written for a book kept in another currency.
  test('a book whose functional currency is not euro is refused, named', () {
    for (final currency in ['CHF', 'DKK']) {
      final fec = buildFecFromPostings(
        set.postings,
        accountNames: const {},
        parties: parties,
        functionalCurrency: currency,
      );
      expect(fec.file, isEmpty);
      expect(fec.blockers, [FecBlocker(FecBlock.currency, currency)]);
    }
  });
}
