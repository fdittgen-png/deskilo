// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — every accounting exporter reads its input from ONE source: the
// year's `accounting_source_snapshot_v1` response, and for a posted format
// of an issuer keeping a local book the postings of `compute_postings`,
// each read once. The fakes below fail the test on a second read of the
// same period, and every format of the registry runs through them, with
// and without a local book. A second guard reads the export run's own
// source: it reaches the books only through that one reader, so a format
// cannot quietly add a read of its own (matches, instalments, ledger).
import 'dart:io';

import 'package:deskilo/core/time/date_text.dart';
import 'package:deskilo/features/money/application/accounting_export_source.dart';
import 'package:deskilo/features/money/application/generic_journal_export.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/domain/accounting_source_queries.dart';
import 'package:deskilo/features/money/domain/accounting_source_snapshot.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/domain/book_profile_repository.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/saf_t_financial.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

const _ws = 'ws-1';

/// The formats written from the posting engine when the issuer keeps a
/// local book; the generic journal has no other source.
const _postedWhenLocalBook = {
  'fec',
  'saft',
  'bundle',
  'generic_journal_csv',
  // #2376 — the books printed from the postings.
  'general_ledger',
  'trial_balance',
  'journals',
  // #2379 — the SAF-T Financial files, written from the postings only.
  'saft_no',
  'faia_lu',
  'saft_oecd_full',
};

/// The posted formats that also read the chart's names and the parties.
const _named = {
  'fec',
  'bundle',
  'general_ledger',
  'trial_balance',
  'journals',
  // #2379 — they name the accounts and the parties too.
  'saft_no',
  'faia_lu',
  'saft_oecd_full',
};

BookProfile _localBook({int startMonth = 1}) => BookProfile(
  id: 'p',
  workspaceId: _ws,
  issuerSiteId: 'site',
  authority: BookAuthority.localBook,
  externalSystem: '',
  functionalCurrency: 'EUR',
  fiscalYearStartMonth: startMonth,
  fiscalYearStartDay: 1,
  basis: AccountingBasis.accrual,
  effectiveFrom: DateTime(2026),
  revision: 1,
);

/// Counts every read; a second read of the same kind for the same
/// [period] fails the test.
class _Reads {
  final counts = <String, int>{};
  final _seen = <String>{};
  void once(String what, [String period = '']) {
    counts[what] = (counts[what] ?? 0) + 1;
    if (!_seen.add('$what $period')) {
      fail('a second $what read for the same period');
    }
  }
}

class _Snapshot implements AccountingSourceQueries {
  _Snapshot(this.reads, this.held, {required this.local});
  final _Reads reads;
  final List<Invoice> held;
  final bool local;

  @override
  Future<AccountingSourceSnapshot> fetchAccountingSource({
    required String workspaceId,
    required int year,
  }) async {
    reads.once('snapshot');
    return AccountingSourceSnapshot.demo(
      invoices: [
        for (final i in held)
          (id: i.id, number: i.number, totalCents: i.totalCents),
      ],
      ledger: const [],
      repartitions: const [],
      bookProfiles: local ? [_localBook()] : const [],
      matches: {
        for (final i in held)
          i.id: InvoiceMatch(
            invoiceId: i.id,
            paidCents: i.totalCents,
            resolution: 'exact',
            matchedAt: DateTime(2026, 6),
          ),
      },
      instalments: {
        held.first.id: [
          TaxPointPayment(DateTime(2026, 6), held.first.totalCents),
        ],
      },
    );
  }
}

class _Books implements BookProfileRepository {
  _Books(this.reads);
  final _Reads reads;

  @override
  Future<PostingSet> fetchPostings(
    String w,
    String i,
    DateTime f,
    DateTime t,
  ) async {
    reads.once('postings', '${isoDay(f)}..${isoDay(t)}');
    return const PostingSet([], []);
  }

  @override
  Future<({List<BookAccount> accounts, List<BookMapping> mappings})>
  fetchBookChart(String workspaceId) async {
    reads.once('chart');
    return (accounts: const <BookAccount>[], mappings: const <BookMapping>[]);
  }

  @override
  Future<Map<String, PostingParty>> fetchPostingParties(
    String workspaceId,
    List<String> documentIds,
  ) async {
    reads.once('parties');
    return const {};
  }

  // Any other call is not a read an export makes.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('an export called ${invocation.memberName}');
}

String _source(String path) => File(path).readAsStringSync();

void main() {
  final held = SeededExportYear.invoices;
  // The formats the run writes: an API target or one awaiting its
  // specification has no file.
  final formats = {for (final t in accountingTargets) ?t.format?.id};

  test('the registry is the run\'s dispatch: no format escapes the table', () {
    final dispatched = {
      for (final m in RegExp(r"case '(\w+)':").allMatches(
        _source('lib/features/money/presentation/accounting_export_run.dart'),
      ))
        m.group(1)!,
    };
    expect(dispatched, formats);
    // Every format any country is offered is in the table.
    for (final country in [
      'FR',
      'DE',
      'AT',
      'PT',
      'GB',
      'CH',
      'ES',
      'IT',
      'US',
    ]) {
      expect(formats, containsAll(formatsFor(country).map((f) => f.id)));
    }
  });

  for (final local in [false, true]) {
    for (final id in formats) {
      test('$id${local ? ', local book' : ''}: one snapshot'
          '${local && _postedWhenLocalBook.contains(id) ? ' and one postings read' : ''}'
          ', nothing read twice', () async {
        final reads = _Reads();
        final input =
            await AccountingExportSource(
              _Snapshot(reads, held, local: local),
              () => GenericJournalExport(_Books(reads)),
            ).read(
              formatId: id,
              workspaceId: _ws,
              country: 'FR',
              year: 2026,
              invoices: held,
            );

        final posted = local && _postedWhenLocalBook.contains(id);
        expect(reads.counts['snapshot'], 1);
        expect(reads.counts['postings'] ?? 0, posted ? 1 : 0);
        final fec = posted && _named.contains(id);
        expect(reads.counts['chart'] ?? 0, fec ? 1 : 0);
        expect(reads.counts['parties'] ?? 0, fec ? 1 : 0);

        // What the files are written from is that one answer.
        expect(input, isNotNull);
        final books = input!.books;
        expect(books.invoices.map((i) => i.id), held.map((i) => i.id));
        expect(books.matches.keys, held.map((i) => i.id));
        expect(books.instalments.keys, [held.first.id]);
        expect(books.bookProfiles, hasLength(local ? 1 : 0));
        expect(
          input.posted,
          posted
              ? isA<JournalPosted>()
              : id == 'generic_journal_csv' || safTFinancialFormats.contains(id)
              ? isA<JournalNeedsLocalBook>()
              : isNull,
        );
        // Only the archive holds its fiscal years, the posted one last.
        expect(
          input.archiveYears,
          id == 'bundle' && posted ? [same(input.posted)] : isEmpty,
        );
      });
    }
  }

  test(
    'a German archive carries no FEC: its local book is not read for one',
    () async {
      final reads = _Reads();
      final input =
          await AccountingExportSource(
            _Snapshot(reads, held, local: true),
            () => GenericJournalExport(_Books(reads)),
          ).read(
            formatId: 'bundle',
            workspaceId: _ws,
            country: 'DE',
            year: 2026,
            invoices: held,
          );
      expect(reads.counts, {'snapshot': 1});
      expect(input!.posted, isNull);
    },
  );

  test('the archive of a calendar year reads every fiscal year it overlaps, '
      'once each, and the chart and the parties once', () async {
    final reads = _Reads();
    final years = await GenericJournalExport(_Books(reads)).readArchiveYears(
      _ws,
      [_localBook(startMonth: 10)],
      2026,
      asOf: DateTime(2026, 11, 5),
    );
    expect(
      [for (final y in years) (y as JournalPosted).year.toString()],
      [
        'FiscalYear(2025-10-01..2026-09-30)',
        'FiscalYear(2026-10-01..2027-09-30)',
      ],
    );
    expect(reads.counts, {'postings': 2, 'chart': 1, 'parties': 1});

    // Before the next fiscal year has a document, only the one that opens
    // the calendar year is read.
    final early = _Reads();
    final one = await GenericJournalExport(_Books(early)).readArchiveYears(
      _ws,
      [_localBook(startMonth: 10)],
      2026,
      asOf: DateTime(2026, 8, 10),
    );
    expect(one, hasLength(1));
    expect(early.counts['postings'], 1);
  });

  test(
    'the counting fake does fail on a second read (the guard can fire)',
    () async {
      final reads = _Reads();
      final source = _Snapshot(reads, held, local: false);
      await source.fetchAccountingSource(workspaceId: _ws, year: 2026);
      await expectLater(
        source.fetchAccountingSource(workspaceId: _ws, year: 2026),
        throwsA(isA<TestFailure>()),
      );
    },
  );

  test('the export run reaches the books only through the one reader', () {
    final run = _source(
      'lib/features/money/presentation/accounting_export_run.dart',
    );
    final journal = _source(
      'lib/features/money/presentation/accounting_export_journal.dart',
    );
    final fec = _source(
      'lib/features/money/presentation/accounting_export_fec.dart',
    );
    // The one reader, once.
    expect('accountingExportSourceProvider'.allMatches(run), hasLength(1));
    for (final text in [run, journal, fec]) {
      for (final forbidden in [
        'invoiceMatchesProvider',
        'accountingSourceQueriesProvider',
        'bookProfileRepositoryProvider',
        'fetchInvoiceInstalments',
        'fetchAccountingSource',
        'fetchPostings',
        'fetchWorkspaceLedger',
        'fetchBookProfiles',
      ]) {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
    }
    // The only reads left in the run are the accountant handoff's recheck
    // (#1640): it re-reads AFTER the file is built and reviewed, to refuse
    // the save if the books moved; it never feeds the file.
    expect(
      [for (final m in RegExp(r'\.(fetch\w+)\(').allMatches(run)) m.group(1)],
      ['fetchInvoices', 'fetchInvoiceMatches'],
    );
  });
}
