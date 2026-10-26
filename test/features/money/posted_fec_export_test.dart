// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the posted FEC through the export run's own helpers: saved under
// its closing day for its fiscal year, with the person told when the year
// is still open; refused, named, when a party has no client code or the
// file breaks the import contract; and in the year archive, logged once
// when the year is closed, carried again with the same bytes, refused when
// the closed year's books changed since.
import 'dart:convert';

import 'package:deskilo/features/money/application/book_period_commands.dart';
import 'package:deskilo/features/money/application/generic_journal_export.dart';
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:deskilo/features/money/domain/archive_fec.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_period.dart';
import 'package:deskilo/features/money/domain/fiscal_year.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/presentation/accounting_export_fec.dart';
import 'package:deskilo/features/money/providers/book_period_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _year = FiscalYear(DateTime(2025, 10), DateTime(2026, 9, 30));
const _scope = (workspaceId: 'ws', legalId: '812 345 678', development: false);

AccountingAmount _eur(int minor) => AccountingAmount('EUR', minor);

PostingLine _line(BookRole role, String account, int debit, int credit) =>
    PostingLine(
      role: role,
      accountCode: account,
      debit: _eur(debit),
      credit: _eur(credit),
    );

/// The fiscal year after [_year], still running.
final _nextYear = FiscalYear(DateTime(2026, 10), DateTime(2027, 9, 30));

/// INV-1 of 120.00, paid on 20 March: two balanced entries, in [year].
JournalPosted _books({
  String number = 'M-0001',
  DateTime? sold,
  DateTime? paid,
  FiscalYear? year,
}) =>
    JournalPosted(
      [
        Posting(
          journal: PostingJournal.sales,
          date: sold ?? DateTime(2026, 3, 5),
          kind: PostingKind.invoice,
          documentId: 'inv-1',
          documentNumber: 'INV-1',
          lines: [
            _line(BookRole.customers, '411000', 12000, 0),
            _line(BookRole.revenue, '706000', 0, 10000),
            _line(BookRole.vatOutput, '445711', 0, 2000),
          ],
        ),
        Posting(
          journal: PostingJournal.bank,
          date: paid ?? DateTime(2026, 3, 20),
          kind: PostingKind.receipt,
          documentId: 'inv-1',
          documentNumber: 'INV-1',
          lines: [
            _line(BookRole.bank, '512000', 12000, 0),
            _line(BookRole.customers, '411000', 0, 12000),
          ],
        ),
      ],
      year: year ?? _year,
      accountNames: const {
        '411000': 'Clients',
        '706000': 'Prestations',
        '445711': 'TVA 20 %',
        '512000': 'Banque',
      },
      parties: {
        'inv-1': PostingParty(kind: 'member', number: number, name: 'Ana'),
      },
      functionalCurrency: 'EUR',
    );

class _Log implements BookPeriodRepository {
  final records = <BookExportRecord>[];

  @override
  Future<String?> recordExport(
    String workspaceId,
    BookExportRecord record,
  ) async {
    records.add(record);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('unexpected ${invocation.memberName}');
}

BookPeriodsOverview _closed({List<BookExport> exports = const []}) =>
    BookPeriodsOverview(
      periods: [
        BookPeriod(
          id: 'p',
          from: _year.from,
          to: _year.to,
          reason: BookPeriodReason.owner,
        ),
      ],
      exports: exports,
    );

Future<void> _run(
  WidgetTester tester,
  Future<void> Function(BuildContext context, WidgetRef ref) action, {
  BookPeriodsOverview periods = const BookPeriodsOverview(),
  _Log? log,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookPeriodsProvider.overrideWith((ref, ws) async => periods),
        bookPeriodCommandProvider.overrideWithValue(
          BookPeriodCommands(log ?? _Log()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => action(context, ref),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('an open year\'s FEC is saved under its closing day, and the '
      'person is told it is provisional', (tester) async {
    final saved = <(String, FiscalYear)>[];
    await _run(
      tester,
      (context, ref) => FecExportActions(context, ref, _scope).exportPosted(
        _books(),
        save: (content, name, year) async => saved.add((name, year)),
      ),
    );
    expect(saved, [('812345678FEC20260930.txt', _year)]);
    expect(find.text(l10n.fecProvisional), findsOneWidget);
  });

  testWidgets('a closed year\'s FEC is saved with nothing to qualify', (
    tester,
  ) async {
    final saved = <String>[];
    await _run(
      tester,
      periods: _closed(),
      (context, ref) => FecExportActions(context, ref, _scope).exportPosted(
        _books(),
        save: (content, name, year) async => saved.add(content),
      ),
    );
    expect(saved.single, startsWith('JournalCode\t'));
    expect(saved.single, contains('\t411M0001\tAna\t'));
    expect(find.text(l10n.fecProvisional), findsNothing);
  });

  testWidgets('a party without a client code stops the FEC, named', (
    tester,
  ) async {
    final saved = <String>[];
    await _run(
      tester,
      (context, ref) => FecExportActions(context, ref, _scope).exportPosted(
        _books(number: ''),
        save: (content, name, year) async => saved.add(content),
      ),
    );
    expect(saved, isEmpty);
    expect(find.text(l10n.journalFecPartyCode('Ana ()')), findsOneWidget);
  });

  testWidgets('a FEC that breaks the import contract is not saved, and the '
      'rule is named', (tester) async {
    final saved = <String>[];
    await _run(
      tester,
      // A sale dated before the fiscal year opens.
      (context, ref) => FecExportActions(context, ref, _scope).exportPosted(
        _books(sold: DateTime(2025, 9, 30)),
        save: (content, name, year) async => saved.add(content),
      ),
    );
    expect(saved, isEmpty);
    expect(find.text(l10n.fecContractFailed('dates')), findsOneWidget);
  });

  group('the year archive', () {
    Future<(bool, Map<String, List<int>>)> archive(
      WidgetTester tester, {
      required BookPeriodsOverview periods,
      required _Log log,
      String country = 'FR',
      List<GenericJournal>? years,
    }) async {
      late bool made;
      final files = <String, List<int>>{};
      await _run(
        tester,
        periods: periods,
        log: log,
        (context, ref) async =>
            made = await FecExportActions(context, ref, _scope).addYearFec(
              files,
              country: country,
              years: years ?? [_books()],
              year: 2026,
              documents: (
                fec: () => fail('the posted FEC is the archive\'s'),
                thirdParties: const {},
              ),
            ),
      );
      return (made, files);
    }

    testWidgets('a closed year logs its final FEC once', (tester) async {
      final log = _Log();
      final (made, files) = await archive(tester, periods: _closed(), log: log);
      expect(made, isTrue);
      expect(
        files.keys,
        containsAll(['812345678FEC20260930.txt', 'fec-manifest.txt']),
      );
      final record = log.records.single;
      expect(record.formatId, archiveFecFormatId);
      expect((record.from, record.to), (_year.from, _year.to));

      // A second archive finds that log, carries the same bytes, logs
      // nothing more.
      final again = _Log();
      final logged = BookExport(
        id: 'e',
        formatId: archiveFecFormatId,
        from: _year.from,
        to: _year.to,
        sha256: record.sha256,
        byteCount: record.bytes,
        rowCount: record.rows,
        documentCount: 0,
        closedPeriod: true,
        exportedAt: DateTime.utc(2026, 10, 15),
      );
      final (madeAgain, filesAgain) = await archive(
        tester,
        periods: _closed(exports: [logged]),
        log: again,
      );
      expect(madeAgain, isTrue);
      expect(again.records, isEmpty);
      expect(
        filesAgain['812345678FEC20260930.txt'],
        files['812345678FEC20260930.txt'],
      );
    });

    testWidgets('a closed year whose FEC changed since its log is not '
        'archived', (tester) async {
      final log = _Log();
      final (made, files) = await archive(
        tester,
        periods: _closed(
          exports: [
            BookExport(
              id: 'e',
              formatId: archiveFecFormatId,
              from: _year.from,
              to: _year.to,
              sha256: '0' * 64,
              byteCount: 1,
              rowCount: 1,
              documentCount: 0,
              closedPeriod: true,
              exportedAt: DateTime.utc(2026, 10, 15),
            ),
          ],
        ),
        log: log,
      );
      expect(made, isFalse);
      expect(files, isEmpty);
      expect(log.records, isEmpty);
      expect(find.text(l10n.fecArchiveChanged('2026-10-15')), findsOneWidget);
    });

    testWidgets('an open year travels as provisional, never logged; a '
        'German archive has no FEC', (tester) async {
      final log = _Log();
      final (made, files) = await archive(
        tester,
        periods: const BookPeriodsOverview(),
        log: log,
      );
      expect(made, isTrue);
      expect(files.keys, contains('PROVISOIRE-812345678FEC20260930.txt'));
      expect(log.records, isEmpty);
      final (madeDe, filesDe) = await archive(
        tester,
        periods: _closed(),
        log: log,
        country: 'DE',
      );
      expect(madeDe, isTrue);
      expect(filesDe, isEmpty);
    });

    // A fiscal year from 1 October: the archive of 2026 holds the year that
    // closed on 30 September and the one running since 1 October.
    final straddling = [
      _books(),
      _books(
        sold: DateTime(2026, 11, 5),
        paid: DateTime(2026, 11, 20),
        year: _nextYear,
      ),
    ];

    testWidgets('the archive of a calendar year carries every fiscal year it '
        'overlaps: the closed one final and logged, the running one '
        'provisional', (tester) async {
      final log = _Log();
      final (made, files) = await archive(
        tester,
        periods: _closed(),
        log: log,
        years: straddling,
      );
      expect(made, isTrue);
      expect(files.keys, {
        '812345678FEC20260930.txt',
        'PROVISOIRE-812345678FEC20270930.txt',
        'fec-manifest.txt',
      });
      final record = log.records.single;
      expect((record.from, record.to), (_year.from, _year.to));
      final manifest = utf8.decode(files['fec-manifest.txt']!);
      expect(
        RegExp('^fiscal_year: (.*)\$', multiLine: true)
            .allMatches(manifest.replaceAll('\r', ''))
            .map((m) => m.group(1)),
        ['2025-10-01..2026-09-30', '2026-10-01..2027-09-30'],
      );
      expect(
        RegExp('^status: (.*)\$', multiLine: true)
            .allMatches(manifest.replaceAll('\r', ''))
            .map((m) => m.group(1)),
        ['final', 'provisional'],
      );
    });

    testWidgets('a fiscal year the engine could not post stops the archive, '
        'named; posted years pass', (tester) async {
      final blocked = <bool>[];
      await _run(tester, (context, ref) async {
        final actions = FecExportActions(context, ref, _scope);
        blocked
          ..add(actions.archiveYearBlocked(straddling))
          ..add(
            actions.archiveYearBlocked([
              const JournalNeedsRates(['B-2 (CHF)']),
              _books(),
            ]),
          );
      });
      expect(blocked, [false, true]);
      expect(find.text(l10n.journalNeedsRates('B-2 (CHF)')), findsOneWidget);
    });

    testWidgets('a changed closed year stops the whole archive, and nothing '
        'is logged', (tester) async {
      final log = _Log();
      final (made, files) = await archive(
        tester,
        periods: BookPeriodsOverview(
          periods: [
            BookPeriod(
              id: 'p',
              from: _year.from,
              to: _year.to,
              reason: BookPeriodReason.owner,
            ),
            BookPeriod(
              id: 'q',
              from: _nextYear.from,
              to: _nextYear.to,
              reason: BookPeriodReason.owner,
            ),
          ],
          exports: [
            BookExport(
              id: 'e',
              formatId: archiveFecFormatId,
              from: _nextYear.from,
              to: _nextYear.to,
              sha256: '0' * 64,
              byteCount: 1,
              rowCount: 1,
              documentCount: 0,
              closedPeriod: true,
              exportedAt: DateTime.utc(2027, 10, 15),
            ),
          ],
        ),
        log: log,
        years: straddling,
      );
      expect(made, isFalse);
      expect(files, isEmpty);
      expect(log.records, isEmpty);
      expect(find.text(l10n.fecArchiveChanged('2027-10-15')), findsOneWidget);
    });
  });
}
