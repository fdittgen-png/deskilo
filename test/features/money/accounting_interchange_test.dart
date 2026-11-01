// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the interchange envelope of the seeded year: built from the
// engine's postings as read (nothing derived again), refused before any
// file when it is inconsistent (one rule per case, one thing varied), and
// the generic journal written from it.
import 'package:deskilo/features/money/application/generic_journal_export.dart';
import 'package:deskilo/features/money/domain/accounting_interchange.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/domain/fiscal_year.dart';
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

final _set = postingsOf(
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

final _book = BookProfile(
  id: 'profile-1',
  workspaceId: 'ws',
  issuerSiteId: 'site',
  authority: BookAuthority.localBook,
  externalSystem: '',
  functionalCurrency: 'EUR',
  fiscalYearStartMonth: 1,
  fiscalYearStartDay: 1,
  basis: AccountingBasis.accrual,
  effectiveFrom: DateTime(2026),
  revision: 3,
);

const _party = PostingParty(kind: 'member', number: 'M-7', name: 'Ada');

AccountingInterchangeV1 _envelope({
  String issuer = 'site',
  int revision = 3,
  String currency = 'EUR',
  List<Posting>? postings,
}) => AccountingInterchangeV1.fromPostings(
  book: InterchangeBook(
    issuerSiteId: issuer,
    profileId: 'profile-1',
    revision: revision,
    functionalCurrency: currency,
  ),
  period: FiscalYear.calendar(2026),
  postings: postings ?? _set.postings,
);

void main() {
  test('the seeded year: the postings as read, one reference per document', () {
    expect(_set.blockers, isEmpty);
    final first = _set.postings.first;
    final books = JournalPosted(
      _set.postings,
      year: FiscalYear.calendar(2026),
      parties: {first.documentId: _party},
      book: _book,
    );
    final e = interchangeOf(books);
    expect(AccountingInterchangeV1.schema, 'accounting_interchange_v1');
    expect(e.book.issuerSiteId, 'site');
    expect(e.book.profileId, 'profile-1');
    expect(e.book.revision, 3);
    expect(e.period, FiscalYear.calendar(2026));
    expect(e.book.functionalCurrency, 'EUR');
    // The postings themselves, not a copy computed again.
    expect(e.postings, hasLength(_set.postings.length));
    for (var i = 0; i < e.postings.length; i++) {
      expect(identical(e.postings[i], _set.postings[i]), isTrue);
    }
    final ids = [
      ...{for (final p in _set.postings) p.documentId},
    ];
    expect([for (final d in e.documents) d.id], ids);
    expect(e.documents.first.number, first.documentNumber);
    expect(e.documents.first.events, [
      for (final p in _set.postings)
        if (p.documentId == first.documentId) p.kind,
    ]);
    expect(e.documents.first.party, same(_party));
    expect(e.documents.skip(1).every((d) => d.party == null), isTrue);
    expect(e.attachments, isEmpty, reason: 'no read loads them yet');
    expect(e.validate(), isEmpty);
  });

  group('validate refuses', () {
    test('an envelope without an issuer', () {
      expect(_envelope(issuer: ' ').validate(), [
        const InterchangeProblem(InterchangeBlock.missingIssuer, ''),
      ]);
    });

    test('a book profile without a revision', () {
      expect(_envelope(revision: 0).validate(), [
        const InterchangeProblem(InterchangeBlock.missingRevision, 'profile-1'),
      ]);
    });

    test('an entry that does not balance', () {
      final p = _set.postings.first;
      final short = Posting(
        journal: p.journal,
        date: p.date,
        kind: p.kind,
        documentId: p.documentId,
        documentNumber: p.documentNumber,
        lines: p.lines.sublist(0, p.lines.length - 1),
      );
      expect(
        _envelope(postings: [short, ..._set.postings.skip(1)]).validate(),
        [
          InterchangeProblem(
            InterchangeBlock.unbalancedEntry,
            '${p.documentNumber} ${p.kind.wire}',
          ),
        ],
      );
    });

    test('lines in another currency than the book', () {
      final problems = _envelope(currency: 'CHF').validate();
      expect(problems.map((p) => p.block).toSet(), {
        InterchangeBlock.unconvertedCurrency,
      });
      expect(
        problems,
        contains(
          InterchangeProblem(
            InterchangeBlock.unconvertedCurrency,
            '${_set.postings.first.documentNumber} (EUR)',
          ),
        ),
      );
    });

    test('a posting of a document the envelope does not carry', () {
      final e = _envelope();
      final missing = e.documents.first.id;
      final cut = AccountingInterchangeV1(
        book: e.book,
        period: e.period,
        documents: e.documents.skip(1).toList(),
        postings: e.postings,
      );
      expect(cut.validate(), [
        InterchangeProblem(InterchangeBlock.unknownDocument, missing),
      ]);
    });
  });

  group('the generic journal is written from the envelope', () {
    test('a read on a book profile gives the file of its envelope', () {
      final out = journalFileOf(
        JournalPosted(
          _set.postings,
          year: FiscalYear.calendar(2026),
          book: _book,
        ),
      );
      expect((out as JournalFile).content, buildGenericJournalCsv(_envelope()));
    });

    test('postings with no book profile are refused, nothing written', () {
      final out = journalFileOf(
        JournalPosted(_set.postings, year: FiscalYear.calendar(2026)),
      );
      // No profile: no issuer, no revision and no book currency either.
      expect(
        (out as JournalInterchangeRefused).problems.map((p) => p.block).toSet(),
        {
          InterchangeBlock.missingIssuer,
          InterchangeBlock.missingRevision,
          InterchangeBlock.unconvertedCurrency,
        },
      );
    });

    test('what stops the postings passes through', () {
      expect(
        journalFileOf(const JournalNeedsLocalBook()),
        isA<JournalNeedsLocalBook>(),
      );
    });
  });
}
