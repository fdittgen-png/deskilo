// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the posting rules over the seeded year every exporter is driven
// over. Expected entries are worked by hand: INV-1 at 20 % and 5.5 % with a
// netted payment (40.00) and a netted expense (30.00, booked by its
// receipt, never here: 0524) then paid 155.50;
// INV-2 part-paid; INV-3 paid 60.00 and the rest written off; CN-1 a credit
// note of 50.00. Every entry balances; a qualified role is used where it is
// mapped and its base elsewhere; a missing base blocks with its name.
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/posting_rules.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:flutter_test/flutter_test.dart';

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

BookMapping _map(BookRole role, String code, {String? qualifier}) =>
    BookMapping(
      id: '${role.wire}:$qualifier',
      workspaceId: 'ws',
      issuerSiteId: 'site',
      role: role,
      qualifier: qualifier,
      accountId: 'acc-$code',
      effectiveFrom: DateTime(2020),
      revision: 1,
    );

final _accounts = [
  _account('411', AccountType.asset),
  _account('512', AccountType.asset),
  _account('706', AccountType.income),
  _account('7061', AccountType.income),
  _account('44571', AccountType.liability),
  _account('445712', AccountType.liability),
  _account('625', AccountType.expense),
  _account('654', AccountType.expense),
  _account('44574', AccountType.liability),
];

List<BookMapping> _chart({bool writeOff = true}) => [
  _map(BookRole.customers, '411'),
  _map(BookRole.bank, '512'),
  _map(BookRole.revenue, '706'),
  _map(BookRole.revenue, '7061', qualifier: 'reduced'),
  _map(BookRole.vatOutput, '44571'),
  _map(BookRole.vatOutput, '445712', qualifier: 'reduced'),
  _map(BookRole.expenses, '625'),
  if (writeOff) _map(BookRole.writeOff, '654'),
  _map(BookRole.vatPending, '44574'),
];

String _group(InvoiceVatTotal t) => t.percent >= 20 ? 'standard' : 'reduced';

PostingSet _post({bool writeOff = true, VatTaxPointIndex? taxPoints}) =>
    postingsOf(
      invoices: SeededExportYear.invoices,
      matches: SeededExportYear.matches,
      book: PostingBook(
        accounts: _accounts,
        mappings: _chart(writeOff: writeOff),
        issuerSiteId: 'site',
      ),
      groupOf: _group,
      taxPoints: taxPoints,
    );

/// "account:D1234" / "account:C1234" for each line, in order.
List<String> _lines(Posting p) => [
  for (final l in p.lines)
    '${l.accountCode}:${l.debit.minor != 0 ? 'D${l.debit.minor}' : 'C${l.credit.minor}'}',
];

void main() {
  final set = _post();
  Posting entry(String number, PostingKind kind, [DateTime? on]) =>
      set.postings.singleWhere(
        (p) =>
            p.documentNumber == number &&
            p.kind == kind &&
            (on == null || p.date == on),
      );

  test(
    'the full chart books the year without a blocker, every entry balanced',
    () {
      expect(set.blockers, isEmpty);
      expect(set.postings, hasLength(9));
      expect(set.postings.every((p) => p.balanced), isTrue);
    },
  );

  final table = <String, (String, PostingKind, PostingJournal, List<String>)>{
    'INV-1 per rate group; the reduced rate on its qualified accounts': (
      'INV-1',
      PostingKind.invoice,
      PostingJournal.sales,
      ['411:D22550', '706:C10000', '44571:C2000', '7061:C10000', '445712:C550'],
    ),
    'its netted payment is money in on the invoice day': (
      'INV-1@0305',
      PostingKind.receipt,
      PostingJournal.bank,
      ['512:D4000', '411:C4000'],
    ),
    'INV-3 written off: 40.00 left, 6.66 of output tax regularised': (
      'INV-3',
      PostingKind.writeOff,
      PostingJournal.other,
      ['654:D3334', '44571:D666', '411:C4000'],
    ),
    'CN-1 mirrors an invoice': (
      'CN-1',
      PostingKind.creditNote,
      PostingJournal.sales,
      ['411:C5000', '706:D4167', '44571:D833'],
    ),
  };
  for (final MapEntry(key: name, value: (number, kind, journal, lines))
      in table.entries) {
    test(name, () {
      final p = number.endsWith('@0305')
          ? entry('INV-1', kind, DateTime(2026, 3, 5))
          : entry(number, kind);
      expect(p.journal, journal);
      expect(_lines(p), lines);
    });
  }

  test('the receipts are dated on their match, INV-2 stays open for 80.00', () {
    expect(_lines(entry('INV-1', PostingKind.receipt, DateTime(2026, 3, 20))), [
      '512:D15550',
      '411:C15550',
    ]);
    final inv2 = set.postings.where((p) => p.documentNumber == 'INV-2');
    var owed = 0;
    for (final p in inv2) {
      for (final l in p.lines.where((l) => l.accountCode == '411')) {
        owed += l.debit.minor - l.credit.minor;
      }
    }
    expect(owed, 8000);
  });

  test('a netted expense credit books no expense: the member\'s receipt '
      'did (0524)', () {
    expect(set.postings.where((p) => p.kind == PostingKind.expense), isEmpty);
  });

  test('on receipts, the tax waits on vat_pending and leaves it on its tax '
      'point, one entry per rate group (0521)', () {
    final inv1 = SeededExportYear.invoices.singleWhere(
      (i) => i.number == 'INV-1',
    );
    final paid = DateTime(2026, 3, 20);
    final deferred = _post(
      taxPoints: VatTaxPointIndex([
        for (final (percent, gross, net) in [
          (20.0, 12000, 10000),
          (5.5, 10550, 10000),
        ])
          VatTaxPointAmount(
            invoiceId: inv1.id,
            on: paid,
            percent: percent,
            grossCents: gross,
            netCents: net,
            vatCents: gross - net,
          ),
      ]),
    );
    Posting only(PostingKind kind) => deferred.postings.singleWhere(
      (p) => p.documentNumber == 'INV-1' && p.kind == kind,
    );
    expect(_lines(only(PostingKind.invoice)), [
      '411:D22550',
      '706:C10000',
      '44574:C2000',
      '7061:C10000',
      '44574:C550',
    ]);
    expect(
      [
        for (final p in deferred.postings)
          if (p.kind == PostingKind.vatRelease) (p.date, _lines(p).join(',')),
      ],
      [
        (paid, '44574:D2000,44571:C2000'),
        (paid, '44574:D550,445712:C550'),
      ],
    );
    expect(
      set.postings.where((p) => p.kind == PostingKind.vatRelease),
      isEmpty,
      reason: 'without tax points everything is due when issued',
    );
  });

  test('a deferred invoice written off clears its unpaid tax from '
      'vat_pending, never from the tax already due (0526)', () {
    final inv3 = SeededExportYear.invoices.singleWhere(
      (i) => i.number == 'INV-3',
    );
    final deferred = _post(
      taxPoints: VatTaxPointIndex([
        VatTaxPointAmount(
          invoiceId: inv3.id,
          on: DateTime(2026, 5, 20),
          percent: 20,
          grossCents: 6000,
          netCents: 5000,
          vatCents: 1000,
        ),
      ]),
    );
    final writeOff = deferred.postings.singleWhere(
      (p) => p.documentNumber == 'INV-3' && p.kind == PostingKind.writeOff,
    );
    expect(_lines(writeOff), ['654:D3334', '44574:D666', '411:C4000']);
  });

  test('a missing base blocks with its name and posts nothing for it', () {
    final blocked = _post(writeOff: false);
    expect(blocked.blockers.map((b) => (b.block, b.subject)), [
      (PostingBlock.unmappedRole, 'write_off'),
    ]);
  });

  test('the server answer reads as the same postings (0518)', () {
    final parsed = PostingSet.fromJson(const {
      'period': {'from': '2026-01-01', 'to': '2026-12-31'},
      'postings': [
        {
          'journal': 'other',
          'kind': 'write_off',
          'date': '2026-05-25',
          'document_id': 'id-INV-3',
          'document_number': 'INV-3',
          'currency': 'EUR',
          'lines': [
            {
              'role': 'write_off',
              'qualifier': null,
              'account_code': '654',
              'debit_cents': 3334,
              'credit_cents': 0,
            },
            {
              'role': 'vat_output',
              'qualifier': 'standard',
              'account_code': '44571',
              'debit_cents': 666,
              'credit_cents': 0,
            },
            {
              'role': 'customers',
              'qualifier': null,
              'account_code': '411',
              'debit_cents': 0,
              'credit_cents': 4000,
            },
          ],
        },
      ],
      'blockers': [
        {'block': 'unmappedRole', 'subject': 'fees'},
      ],
    });
    final p = parsed.postings.single;
    expect(p.kind, PostingKind.writeOff);
    expect(p.journal, PostingJournal.other);
    expect(_lines(p), _lines(entry('INV-3', PostingKind.writeOff)));
    expect(p.lines[1].qualifier, 'standard');
    expect(p.balanced, isTrue);
    expect(parsed.blockers.single.block, PostingBlock.unmappedRole);
  });
}
