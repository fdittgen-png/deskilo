// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3884 -- books this build cannot read in full never export as if complete:
// entries with a role, kind or journal it does not know, a chart account it
// does not know (the postings on it would lose their name and type), and the
// opening period all end in ONE refusal that says how many; the good
// postings beside them do not make the file.
import 'package:deskilo/core/data/unreadable_rows.dart';
import 'package:deskilo/features/money/application/generic_journal_export.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_profile_repository.dart';
import 'package:deskilo/features/money/presentation/accounting_export_journal.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Posting _good(String id) => Posting(
      journal: PostingJournal.sales,
      date: DateTime(2026, 5, 12),
      kind: PostingKind.invoice,
      documentId: id,
      documentNumber: 'N-$id',
      lines: [
        PostingLine(
          role: BookRole.customers,
          accountCode: '411',
          debit: AccountingAmount('EUR', 100),
          credit: AccountingAmount('EUR', 0),
        ),
        PostingLine(
          role: BookRole.revenue,
          accountCode: '706',
          debit: AccountingAmount('EUR', 0),
          credit: AccountingAmount('EUR', 100),
        ),
      ],
    );

PostingSet _good1() => PostingSet([_good('a')], const []);

PostingSet _withUnreadable(int n) => PostingSet(
      [_good('a')],
      [for (var i = 0; i < n; i++) PostingBlocker(PostingBlock.unreadable, 'u$i')],
    );

BookAccount _account(String code) => BookAccount(
      id: 'acc-$code',
      workspaceId: 'ws',
      issuerSiteId: 'site',
      code: code,
      name: 'Name $code',
      type: code == '411' ? AccountType.asset : AccountType.income,
      isPosting: true,
      origin: AccountOrigin.manual,
      revision: 1,
    );

/// Postings answered in turn (the fiscal year, then the opening period).
class _Books implements BookProfileRepository {
  _Books(this.sets);
  final List<PostingSet> sets;
  var _next = 0;

  @override
  Future<PostingSet> fetchPostings(
    String workspaceId,
    String issuerSiteId,
    DateTime from,
    DateTime to,
  ) async => sets[_next++];

  @override
  Future<({List<BookAccount> accounts, List<BookMapping> mappings})>
  fetchBookChart(String workspaceId) async => (
        accounts: [_account('411'), _account('706')],
        mappings: const <BookMapping>[],
      );

  @override
  Future<Map<String, PostingParty>> fetchPostingParties(
    String workspaceId,
    List<String> documentIds,
  ) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('unexpected ${invocation.memberName}');
}

BookProfile _profile(DateTime from) => BookProfile(
      id: 'p-$from',
      workspaceId: 'ws',
      issuerSiteId: 'site',
      authority: BookAuthority.localBook,
      externalSystem: '',
      functionalCurrency: 'EUR',
      fiscalYearStartMonth: 1,
      fiscalYearStartDay: 1,
      basis: AccountingBasis.accrual,
      effectiveFrom: from,
      revision: 1,
    );

Widget _app(Widget Function(BuildContext) button) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: button)),
    );

void main() {
  setUp(UnreadableRows.instance.reset);

  test('good postings beside unreadable entries are not a journal: one '
      'refusal with the count', () async {
    final journal = await GenericJournalExport(_Books([_withUnreadable(2)]))
        .read('ws', [_profile(DateTime(2020))], 2026);
    expect(journal, isA<JournalUnreadable>());
    expect((journal as JournalUnreadable).count, 2);
  });

  test('the opening period with unreadable entries refuses the whole export, '
      'not as an opening that "lacks roles"', () async {
    final journal = await GenericJournalExport(
      _Books([_good1(), _withUnreadable(1)]),
    ).read(
      'ws',
      [_profile(DateTime(2020))],
      2026,
      withOpening: true,
    );
    expect(journal, isA<JournalUnreadable>());
    expect((journal as JournalUnreadable).count, 1);
  });

  test('a chart account this version left out refuses a named export; with '
      'none left out the postings carry their names and types', () async {
    final clean = await GenericJournalExport(_Books([_good1()]))
        .read('ws', [_profile(DateTime(2020))], 2026, named: true);
    expect(clean, isA<JournalPosted>());
    expect((clean as JournalPosted).accountNames['706'], 'Name 706');

    UnreadableRows.instance.record(
      booksAccountsArea('ws'),
      'chart',
      {'acc-9': 'account type future'},
    );
    final refused = await GenericJournalExport(_Books([_good1()]))
        .read('ws', [_profile(DateTime(2020))], 2026, named: true);
    expect(refused, isA<JournalUnreadable>());
    expect((refused as JournalUnreadable).count, 1);
  });

  test('chart rows and posted documents are counted in separate areas', () {
    UnreadableRows.instance
      ..record(booksAccountsArea('ws'), 'chart', {'a': 'x'})
      ..record(booksPostingsArea('ws'), 'p', {'d1': 'x', 'd2': 'x'});
    expect(UnreadableRows.instance.count(booksAccountsArea('ws')), 1);
    expect(UnreadableRows.instance.count(booksPostingsArea('ws')), 2);
    expect(UnreadableRows.instance.count(booksMappingsArea('ws')), 0);
  });

  testWidgets('the journal export says how many entries the books hold that '
      'this version does not know, and saves nothing', (tester) async {
    var saved = false;
    await tester.pumpWidget(_app((context) => TextButton(
          onPressed: () => exportGenericJournal(
            context,
            () async => const JournalUnreadable(3),
            save: (_) async => saved = true,
          ),
          child: const Text('export'),
        )));
    await tester.tap(find.text('export'));
    await tester.pump();
    await tester.pump();
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.journalUnreadableEntries(3)), findsOneWidget);
    expect(saved, isFalse);
  });

  testWidgets('the DATEV export refuses unreadable books before any file is '
      'built, and lets readable ones through', (tester) async {
    final refused = <bool>[];
    await tester.pumpWidget(_app((context) => TextButton(
          onPressed: () {
            refused
              ..add(refuseUnreadableBooks(context, const JournalUnreadable(2)))
              ..add(refuseUnreadableBooks(context, null))
              ..add(refuseUnreadableBooks(context, const JournalBlocked(['x'])));
          },
          child: const Text('datev'),
        )));
    await tester.tap(find.text('datev'));
    await tester.pump();
    expect(refused, [true, false, false]);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.journalUnreadableEntries(2)), findsOneWidget);
  });
}
