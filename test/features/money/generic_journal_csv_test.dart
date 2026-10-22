// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 / #2365 — the generic journal serialises the posting engine's
// entries of the seeded year: one row per line, entries numbered per
// journal, amounts in major units, the rate group as the tax code of a tax
// line, every entry balanced in the file as in the postings.
import 'package:deskilo/features/money/application/generic_journal_export.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/domain/book_profile_repository.dart';
import 'package:deskilo/features/money/domain/generic_journal_csv.dart';
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

void main() {
  final set = postingsOf(
    invoices: SeededExportYear.invoices,
    matches: SeededExportYear.matches,
    book: PostingBook(
      accounts: [
        _account('411', AccountType.asset),
        _account('512', AccountType.asset),
        _account('706', AccountType.income),
        _account('7061', AccountType.income),
        _account('44571', AccountType.liability),
        _account('625', AccountType.expense),
        _account('654', AccountType.expense),
      ],
      mappings: [
        _map(BookRole.customers, '411'),
        _map(BookRole.bank, '512'),
        _map(BookRole.revenue, '706'),
        _map(BookRole.revenue, '7061', qualifier: 'reduced'),
        _map(BookRole.vatOutput, '44571'),
        _map(BookRole.expenses, '625'),
        _map(BookRole.writeOff, '654'),
      ],
      issuerSiteId: 'site',
    ),
    groupOf: (InvoiceVatTotal t) => t.percent >= 20 ? 'standard' : 'reduced',
  );
  final rows = buildGenericJournalCsv(set.postings).trimRight().split('\r\n');

  test('the header and one row per posting line', () {
    expect(set.blockers, isEmpty);
    expect(
      rows.first,
      '"Date","JournalNo","Account","Debit","Credit","Description","Name","Dimension","TaxCode"',
    );
    expect(
      rows,
      hasLength(1 + set.postings.fold<int>(0, (n, p) => n + p.lines.length)),
    );
  });

  test(
    'INV-1: numbered in the sales journal, the reduced rate as its tax code',
    () {
      expect(rows.sublist(1, 6), [
        '"2026-03-05","VE-0001","411","225.50",,"INV-1 invoice",,,',
        '"2026-03-05","VE-0001","706",,"100.00","INV-1 invoice",,,',
        '"2026-03-05","VE-0001","44571",,"20.00","INV-1 invoice",,,"standard"',
        '"2026-03-05","VE-0001","7061",,"100.00","INV-1 invoice",,,',
        '"2026-03-05","VE-0001","44571",,"5.50","INV-1 invoice",,,"reduced"',
      ]);
    },
  );

  test('each journal numbers its own entries', () {
    final numbers = {
      for (final r in rows.skip(1)) r.split(',')[1].replaceAll('"', ''),
    };
    expect(
      numbers,
      containsAll(['VE-0001', 'VE-0004', 'BQ-0001', 'OD-0001']),
    );
  });

  test('every entry balances in the file', () {
    final sums = <String, int>{};
    for (final r in rows.skip(1)) {
      final c = r.replaceAll('"', '').split(',');
      int cents(String s) => s.isEmpty ? 0 : (double.parse(s) * 100).round();
      sums[c[1]] = (sums[c[1]] ?? 0) + cents(c[3]) - cents(c[4]);
    }
    expect(sums.values.every((v) => v == 0), isTrue);
  });

  group('which journal a year gives', () {
    BookProfile profile(BookAuthority authority) => BookProfile(
      id: 'p',
      workspaceId: 'ws',
      issuerSiteId: 'site',
      authority: authority,
      externalSystem: '',
      functionalCurrency: 'EUR',
      fiscalYearStartMonth: 1,
      fiscalYearStartDay: 1,
      basis: AccountingBasis.accrual,
      effectiveFrom: DateTime(2026),
      revision: 1,
    );
    test('no local book, no journal', () async {
      final out = await GenericJournalExport(_Postings(set))
          .of('ws', [profile(BookAuthority.externalBook)], 2026);
      expect(out, isA<JournalNeedsLocalBook>());
    });
    test(
      'a role the engine could not resolve is named, nothing written',
      () async {
        const blocked = PostingSet([], [
          PostingBlocker(PostingBlock.unmappedRole, 'write_off'),
          PostingBlocker(PostingBlock.badAccount, 'write_off'),
        ]);
        final out = await GenericJournalExport(_Postings(blocked))
            .of('ws', [profile(BookAuthority.localBook)], 2026);
        expect((out as JournalBlocked).roles, ['write_off']);
      },
    );
    test('a local book gives the file', () async {
      final out = await GenericJournalExport(_Postings(set))
          .of('ws', [profile(BookAuthority.localBook)], 2026);
      expect(
        (out as JournalFile).content,
        buildGenericJournalCsv(set.postings),
      );
    });
  });
}

class _Postings implements BookProfileRepository {
  _Postings(this.answer);
  final PostingSet answer;

  @override
  Future<PostingSet> fetchPostings(
    String w,
    String i,
    DateTime f,
    DateTime t,
  ) async => answer;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
