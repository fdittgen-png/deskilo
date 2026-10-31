// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3152 — the acquisition tax in the books, worked by hand. A service of
// CHF 1 000.00 bought abroad at 8.1 % owes CHF 81.00 (Ziffer 383):
//   * fully deductible: Dr 1170 81.00 / Cr 2200 81.00;
//   * 60 % deductible:  Dr 1170 48.60, Dr 6500 32.40 / Cr 2200 81.00.
// The entry is on the expense's tax point, in the purchases journal, and
// balances. pgTAP 318 holds the server engine to the same entries.
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/posting_rules.dart';
import 'package:deskilo/features/money/domain/posting_rules_acquisitions.dart';
import 'package:flutter_test/flutter_test.dart';

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

PostingBook _book() => PostingBook(
  accounts: [
    _account('1170', AccountType.asset),
    _account('2200', AccountType.liability),
    _account('6500', AccountType.expense),
  ],
  mappings: [
    _map(BookRole.vatInput, '1170'),
    _map(BookRole.vatOutput, '2200'),
    _map(BookRole.expenses, '6500'),
  ],
  issuerSiteId: 'site',
);

VatAcquisition _acq(String id, int owed, int deductible) => (
  expenseId: id,
  day: DateTime(2026, 3, 12),
  percent: 8.1,
  currency: 'CHF',
  taxOwedCents: owed,
  deductibleCents: deductible,
);

List<String> _lines(Posting p) => [
  for (final l in p.lines)
    '${l.accountCode}:${l.debit.minor != 0 ? 'D${l.debit.minor}' : 'C${l.credit.minor}'}',
];

void main() {
  final postings = acquisitionPostingsOf(
    acquisitions: [
      _acq('aaaaaaaa-0000-4000-8000-000000000001', 8100, 8100),
      _acq('bbbbbbbb-0000-4000-8000-000000000002', 8100, 4860),
    ],
    book: _book(),
    groupOf: (_) => 'normal',
  );

  test('fully deductible: input against output, nothing on expenses', () {
    final p = postings.first;
    expect(p.kind, PostingKind.acquisitionTax);
    expect(p.journal, PostingJournal.purchases);
    expect(p.date, DateTime(2026, 3, 12));
    expect(p.documentNumber, 'aaaaaaaa');
    expect(_lines(p), ['1170:D8100', '2200:C8100']);
  });

  test('60 % deductible: the rest is a cost', () {
    expect(_lines(postings.last), ['1170:D4860', '6500:D3240', '2200:C8100']);
  });

  test('every entry balances', () {
    for (final p in postings) {
      final debit = p.lines.fold<int>(0, (s, l) => s + l.debit.minor);
      final credit = p.lines.fold<int>(0, (s, l) => s + l.credit.minor);
      expect(debit, credit, reason: p.documentNumber);
    }
  });

  test('no tax owed, no entry', () {
    expect(
      acquisitionPostingsOf(
        acquisitions: [_acq('c', 0, 0)],
        book: _book(),
        groupOf: (_) => 'normal',
      ),
      isEmpty,
    );
  });
}
