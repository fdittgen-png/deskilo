// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — where the SAF-T Financial files are offered and what they claim,
// what a Danish space is told, and the one extra postings read that gives
// the opening balances.
import 'package:deskilo/features/money/application/generic_journal_export.dart';
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:deskilo/features/money/domain/accounting_capability.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/domain/accounting_targets_saft.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/domain/book_profile_repository.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/presentation/widgets/accounting_export_sheet.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Posting _posting(String doc, DateTime date) => Posting(
  journal: PostingJournal.sales,
  date: date,
  kind: PostingKind.invoice,
  documentId: 'id-$doc',
  documentNumber: doc,
  lines: [
    PostingLine(
      role: BookRole.customers,
      accountCode: '1500',
      debit: AccountingAmount('EUR', 100),
      credit: AccountingAmount('EUR', 0),
    ),
    PostingLine(
      role: BookRole.revenue,
      accountCode: '3000',
      debit: AccountingAmount('EUR', 0),
      credit: AccountingAmount('EUR', 100),
    ),
  ],
);

/// The book: one sale in the year before, one in the year; every read is
/// recorded.
class _Books implements BookProfileRepository {
  final reads = <(DateTime, DateTime)>[];
  final partyReads = <List<String>>[];

  @override
  Future<PostingSet> fetchPostings(
    String workspaceId,
    String issuerSiteId,
    DateTime from,
    DateTime to,
  ) async {
    reads.add((from, to));
    return PostingSet([
      for (final p in [
        _posting('F-1', DateTime(2025, 11, 3)),
        _posting('F-2', DateTime(2026, 5, 4)),
      ])
        if (!p.date.isBefore(from) && !p.date.isAfter(to)) p,
    ], const []);
  }

  @override
  Future<({List<BookAccount> accounts, List<BookMapping> mappings})>
  fetchBookChart(String workspaceId) async => (
    accounts: [
      for (final (code, type) in const [
        ('1500', AccountType.asset),
        ('3000', AccountType.income),
      ])
        BookAccount(
          id: code,
          workspaceId: workspaceId,
          issuerSiteId: 'site',
          code: code,
          name: 'Account $code',
          type: type,
          isPosting: true,
          origin: AccountOrigin.manual,
          revision: 1,
        ),
    ],
    mappings: const <BookMapping>[],
  );

  @override
  Future<Map<String, PostingParty>> fetchPostingParties(
    String workspaceId,
    List<String> documentIds,
  ) async {
    partyReads.add(documentIds);
    return {
      for (final id in documentIds)
        id: const PostingParty(kind: 'member', number: 'M-1', name: 'Ana'),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('an export called ${invocation.memberName}');
}

final _profile = BookProfile(
  id: 'p',
  workspaceId: 'ws',
  issuerSiteId: 'site',
  authority: BookAuthority.localBook,
  externalSystem: '',
  functionalCurrency: 'EUR',
  fiscalYearStartMonth: 4,
  fiscalYearStartDay: 1,
  basis: AccountingBasis.accrual,
  effectiveFrom: DateTime(2025, 10),
  revision: 1,
);

void main() {
  test("Norway's and Luxembourg's files come first and claim the authority's "
      'format; the OECD tree is an exchange file everywhere', () {
    expect(formatsFor('NO').first.id, 'saft_no');
    expect(formatsFor('LU').first.id, 'faia_lu');
    expect(formatsFor('NO').first.claim, FormatClaim.regulatory);
    for (final country in ['NO', 'LU', 'DK', 'BE']) {
      final full = formatsFor(country)
          .singleWhere((f) => f.id == 'saft_oecd_full');
      expect(full.claim, FormatClaim.exchange);
    }
    for (final id in ['saft_no', 'faia_lu']) {
      final capability = capabilityOfTarget(id);
      expect(capability.state, QualificationState.locallyValidated);
      expect(capability.obligations, {
        Obligation.completePostedBooks,
        Obligation.targetAcceptance,
      });
    }
  });

  test('Denmark is told about the registered system, and no Danish file '
      'claims to meet it', () {
    expect(needsRegisteredSystem('DK'), isTrue);
    expect(needsRegisteredSystem('NO'), isFalse);
    expect(
      formatsFor('DK').where((f) => f.claim == FormatClaim.regulatory),
      isEmpty,
    );
    for (final id in [
      'denmark_registered_system',
      'saft_dk',
      'economic_api',
      'dinero_api',
      'billy_api',
    ]) {
      expect(
        capabilityOfTarget(id).state,
        QualificationState.specificationNeeded,
        reason: id,
      );
    }
  });

  testWidgets('the sheet shows the notice, then the Norwegian file with its '
      'local-book note', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAccountingExportSheet(
                context,
                formats: formatsFor('NO'),
                notices: [l10n.exportDenmarkRegisteredSystem],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.exportDenmarkRegisteredSystem), findsOneWidget);
    expect(find.text(l10n.invoiceExportSafTNo), findsOneWidget);
    expect(find.text(l10n.exportLocalBookOnly), findsOneWidget);
    expect(find.text(l10n.exportNoCompleteBooks), findsNothing);
  });

  test('the opening read covers the book from its first day to the eve of '
      'the fiscal year, and its parties travel with it', () async {
    final books = _Books();
    final read = await GenericJournalExport(books).read(
      'ws',
      [_profile],
      2026,
      named: true,
      withOpening: true,
      asOf: DateTime(2026, 6, 30),
    );
    final posted = read as JournalPosted;
    expect(books.reads, [
      (DateTime(2026, 4), DateTime(2027, 3, 31)),
      (DateTime(2025, 10), DateTime(2026, 3, 31)),
    ]);
    expect(posted.postings.map((p) => p.documentNumber), ['F-2']);
    expect(posted.opening.map((p) => p.documentNumber), ['F-1']);
    expect(posted.parties.keys, containsAll(['id-F-1', 'id-F-2']));
    expect(posted.accountTypes, {
      '1500': AccountType.asset,
      '3000': AccountType.income,
    });
  });

  test('a book that starts with the fiscal year reads no opening', () async {
    final books = _Books();
    final read = await GenericJournalExport(books).read(
      'ws',
      [_profile],
      2025,
      named: true,
      withOpening: true,
      asOf: DateTime(2025, 12, 31),
    );
    expect(books.reads, [(DateTime(2025, 4), DateTime(2026, 3, 31))]);
    expect((read as JournalPosted).opening, isEmpty);
  });
}
