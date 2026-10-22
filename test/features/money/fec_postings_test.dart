// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the FEC of a local book is the engine's postings over the seeded
// year, on the book's own chart: the 18 columns, entries numbered from the
// document they book, every entry balanced, and a receivable lettered with
// its document only when that document's lines on it balance (INV-3, paid
// in part and written off), with DateLet the day of the last of them, and
// naming its member in the auxiliary columns (#2376).
// Expectations by hand.
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
  final file = buildFecFromPostings(
    set.postings,
    accountNames: const {'411000': 'Clients', '512000': 'Banques'},
    parties: {
      inv3.id: const PostingParty(
        kind: 'member',
        number: 'M-0007',
        name: 'Ana Lopez',
      ),
    },
  );
  final rows = [
    for (final line in file.split('\r\n').skip(1)) line.split('\t'),
  ];

  test('the header is the 18 columns of the arrêté', () {
    expect(file.split('\r\n').first, fecColumns.join('\t'));
    expect(rows.every((r) => r.length == 18), isTrue);
    expect(set.blockers, isEmpty);
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
      ('M-0007', 'Ana Lopez'),
    }, reason: 'the receivable names its member in the auxiliary columns');
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
}
