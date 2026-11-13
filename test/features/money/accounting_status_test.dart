// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3616 — the books' status page: each tile says what the page it opens
// says. The periods tile is the last day of the latest period still closed
// (a reopened one does not count); the export tile is the newest row of the
// export history; the bank tile is what the statements list still waits
// for; the numbers tile is the invoice series' next number as its page
// previews it; the VAT tile is the oldest return not filed. A read that
// fails is said on its tile, never shown as nothing to do.
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/money/presentation/screens/accounting_status.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart';
import 'package:deskilo/features/money/providers/book_period_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/vat_declaration_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

class _Periods implements BookPeriodRepository {
  _Periods(this.overview);
  final BookPeriodsOverview overview;

  @override
  Future<BookPeriodsOverview> fetch(String workspaceId) async => overview;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BookPeriod _period(
  String id,
  DateTime from,
  DateTime to, {
  bool reopened = false,
}) => BookPeriod(
  id: id,
  from: from,
  to: to,
  reason: BookPeriodReason.of('owner'),
  reopenedAt: reopened ? DateTime(2026, 9) : null,
);

BookExport _export(String id, DateTime at) => BookExport(
  id: id,
  formatId: 'fec',
  from: DateTime(2026),
  to: DateTime(2026, 3, 31),
  sha256: 'a' * 64,
  byteCount: 100,
  rowCount: 12,
  documentCount: 4,
  closedPeriod: true,
  exportedAt: at,
);

StoredBankStatement _statement(String id, int open) => StoredBankStatement(
  id: id,
  format: BankFileFormat.values.first,
  account: 'CH00',
  currency: 'EUR',
  from: DateTime(2026, 10),
  to: DateTime(2026, 10, 31),
  lineCount: 10,
  openCount: open,
);

VatDeclaration _declaration(String id, DateTime start, String status) =>
    VatDeclaration(
      id: id,
      workspaceId: 'ws-1',
      periodStart: start,
      periodEnd: DateTime(start.year, start.month + 3, 0),
      status: status,
      lines: const [],
      totalNetCents: 0,
      totalVatCents: 0,
      currency: 'EUR',
      invoiceCount: 0,
      createdAt: start,
    );

final _dates = DateFormat.yMd('en');

Future<void> _pump(
  WidgetTester tester, {
  BookPeriodsOverview? periods,
  List<StoredBankStatement> statements = const [],
  List<VatDeclaration> declarations = const [],
  List<NumberSequence> sequences = const [],
  bool bankFails = false,
}) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookPeriodRepositoryProvider.overrideWithValue(
          _Periods(periods ?? const BookPeriodsOverview()),
        ),
        bankStatementsProvider.overrideWith(
          (ref, _) async =>
              bankFails ? throw StateError('unreadable') : statements,
        ),
        vatDeclarationsProvider.overrideWith((ref) async => declarations),
        numberSequencesProvider.overrideWith((ref) async => sequences),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AccountingStatusGrid(
            workspaceId: 'ws-1',
            isOwner: true,
            bankDoor: () {},
            shown: (periods: true, vat: true, numbers: true),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _figure(WidgetTester tester, String tile) => tester
    .widget<Text>(find.byKey(ValueKey('accounting-status-$tile-figure')))
    .data!;

void main() {
  test('the books are closed up to the latest period still closed', () {
    final overview = BookPeriodsOverview(
      periods: [
        _period('q1', DateTime(2026), DateTime(2026, 3, 31)),
        _period('q2', DateTime(2026, 4), DateTime(2026, 6, 30)),
        _period(
          'q3',
          DateTime(2026, 7),
          DateTime(2026, 9, 30),
          reopened: true,
        ),
      ],
    );
    expect(closedUpToOf(overview), DateTime(2026, 6, 30));
    expect(closedUpToOf(const BookPeriodsOverview()), isNull);
  });

  testWidgets('the periods tile and the export tile say what their pages say', (
    tester,
  ) async {
    await _pump(
      tester,
      periods: BookPeriodsOverview(
        periods: [_period('q1', DateTime(2026), DateTime(2026, 3, 31))],
        exports: [
          _export('older', DateTime(2026, 4, 2)),
          _export('newest', DateTime(2026, 5, 9)),
        ],
      ),
    );
    expect(_figure(tester, 'periods'), _dates.format(DateTime(2026, 3, 31)));
    // The export history lists the newest first: the tile is its first row.
    expect(_figure(tester, 'export'), _dates.format(DateTime(2026, 5, 9)));
  });

  testWidgets('the bank tile adds what every statement still waits for', (
    tester,
  ) async {
    await _pump(
      tester,
      statements: [_statement('a', 3), _statement('b', 0), _statement('c', 4)],
    );
    expect(_figure(tester, 'bank'), '7');
  });

  testWidgets('a statements read that fails is said, never "0 to match"', (
    tester,
  ) async {
    await _pump(tester, bankFails: true);
    expect(_figure(tester, 'bank'), 'Could not be read');
  });

  testWidgets('the numbers tile is the invoice series\' next number', (
    tester,
  ) async {
    const series = NumberSequence(
      journal: 'invoice',
      prefix: 'F-',
      reset: NumberReset.never,
      datePart: NumberDatePart.none,
      nextValue: 43,
    );
    await _pump(tester, sequences: [series]);
    expect(_figure(tester, 'numbers'), series.format(43, DateTime(2026)));
  });

  testWidgets('the VAT tile is the oldest return not filed', (tester) async {
    await _pump(
      tester,
      declarations: [
        _declaration('filed', DateTime(2026), 'filed'),
        _declaration('later', DateTime(2026, 7), 'draft'),
        _declaration('oldest', DateTime(2026, 4), 'prepared'),
      ],
    );
    expect(
      _figure(tester, 'vat'),
      contains(_dates.format(DateTime(2026, 4))),
    );
    expect(
      _figure(tester, 'vat'),
      contains(_dates.format(DateTime(2026, 6, 30))),
    );
  });
}
