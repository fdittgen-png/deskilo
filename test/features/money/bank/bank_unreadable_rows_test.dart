// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3913 — the bank reads past a movement or a statement this version cannot
// read: the row is left out of its list, counted and said under the list,
// never read as a status or a format it is not, and one such row no longer
// fails the whole list. A reconciliation report never leaves a movement out:
// it is refused, with what to do next. A write the server took is done even
// when its answer names a status this version does not know: the list is
// read again and shows the written state, never a failure.
import 'package:deskilo/core/data/unreadable_rows.dart';
import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/ui/inline_banner.dart';
import 'package:deskilo/features/money/application/bank_reconciliation_reader.dart';
import 'package:deskilo/features/money/data/bank_rows.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/presentation/widgets/bank_lines_sheet.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _line(String id, String status) => {
  'id': id,
  'position': 1,
  'booking_date': '2026-10-20',
  'value_date': '2026-10-20',
  'amount_cents': 1500,
  'currency': 'CHF',
  'status': status,
};

Map<String, Object?> _statement(String id, String format) => {
  'id': id,
  'format': format,
  'account': 'CH9300762011623852957',
  'currency': 'CHF',
  'period_from': '2026-10-01',
  'period_to': '2026-10-31',
  'lines': 1,
  'open': 1,
};

/// A bank whose reconciliation answers a status this version does not know:
/// the write is done all the same.
class _NewerServer extends FakeBankStatementRepository {
  _NewerServer()
    : super(money: FakeMoneyRepository(), today: DateTime.utc(2026, 10, 26));

  @override
  Future<BankLineStatus?> reconcileOut(
    String lineId, {
    required String outgoingPaymentId,
  }) async {
    await super.reconcileOut(lineId, outgoingPaymentId: outgoingPaymentId);
    return null;
  }
}

Future<StoredBankStatement> _imported(FakeBankStatementRepository bank) async {
  bank.reportedPayments.add((
    payment: OutgoingCandidate(
      id: 'out-1',
      amountCents: 1500,
      paidOn: DateTime.utc(2026, 10, 19),
      reference: 'REIMB-1',
      payee: 'Studio Lumen',
    ),
    currency: 'CHF',
  ));
  final result = await bank.importStatement(
    'ws-1',
    statement: BankStatement(
      format: BankFileFormat.camt054,
      account: 'CH9300762011623852957',
      currency: 'CHF',
      lines: [
        BankLine(
          position: 1,
          bookingDate: DateTime.utc(2026, 10, 20),
          valueDate: DateTime.utc(2026, 10, 20),
          amountCents: -1500,
          currency: 'CHF',
          transactionId: 'O1',
        ),
      ],
    ),
    sourceSha256: 'd' * 64,
    fileName: 'o.xml',
  );
  return (await bank.fetchStatements('ws-1'))
      .singleWhere((s) => s.id == result.statementId);
}

Future<void> _pump(
  WidgetTester tester,
  FakeBankStatementRepository bank,
  StoredBankStatement statement,
) async {
  tester.view.physicalSize = const Size(1200, 3000);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bankStatementRepositoryProvider.overrideWithValue(bank),
        invoicesProvider.overrideWith((ref) async => const []),
        invoiceMatchesProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BankLinesView(
            workspaceId: 'ws-1',
            statement: statement,
            canMatch: false,
            canReconcile: true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(UnreadableRows.instance.clear);

  test('a movement or a statement of a value this version does not know is '
      'no row, never another value', () {
    expect(
      StoredBankLine.fromJson(_line('l1', 'matched'))?.status,
      BankLineStatus.matched,
    );
    expect(StoredBankLine.fromJson(_line('l2', 'disputed')), isNull);
    expect(
      StoredBankStatement.fromJson(_statement('s1', 'camt053'))?.format,
      BankFileFormat.camt053,
    );
    expect(StoredBankStatement.fromJson(_statement('s2', 'swift_mx')), isNull);
  });

  test('a list keeps the rows it reads and counts the one it leaves out', () {
    final kept = readableBankRows(
      [_line('l1', 'open'), _line('l2', 'disputed'), _line('l3', 'matched')],
      StoredBankLine.fromJson,
      area: bankLinesArea('s1'),
      key: 's1',
      what: 'status',
    );
    expect([for (final l in kept) l.id], ['l1', 'l3']);
    expect(UnreadableRows.instance.count(bankLinesArea('s1')), 1);
    // Read again without it: the count describes what is shown now.
    readableBankRows(
      [_line('l1', 'open')],
      StoredBankLine.fromJson,
      area: bankLinesArea('s1'),
      key: 's1',
      what: 'status',
    );
    expect(UnreadableRows.instance.count(bankLinesArea('s1')), 0);
  });

  test('a reconciliation report is refused when a movement or a statement '
      'was left out, never made without it', () async {
    final bank = FakeBankStatementRepository(
      money: FakeMoneyRepository(),
      today: DateTime.utc(2026, 10, 26),
    );
    final statement = await _imported(bank);
    final reader = BankReconciliationReader(bank);
    UnreadableRows.instance.record(bankLinesArea(statement.id), statement.id, {
      'l9': 'status disputed',
    }, scope: statement.id);
    await expectLater(
      reader.read(workspaceId: 'ws-1', statementId: statement.id),
      throwsA(isA<BankRowsUnreadable>()),
    );
    UnreadableRows.instance.clear();
    UnreadableRows.instance.record(bankStatementsArea('ws-1'), 'ws-1', {
      's9': 'format swift_mx',
    }, scope: 'ws-1');
    await expectLater(
      reader.readYear(workspaceId: 'ws-1', year: 2026),
      throwsA(isA<BankRowsUnreadable>()),
    );
  });

  testWidgets('the movements left out are said under the list', (tester) async {
    final bank = FakeBankStatementRepository(
      money: FakeMoneyRepository(),
      today: DateTime.utc(2026, 10, 26),
    );
    final statement = await _imported(bank);
    UnreadableRows.instance.record(bankLinesArea(statement.id), statement.id, {
      'l9': 'status disputed',
    }, scope: statement.id);
    await _pump(tester, bank, statement);
    expect(
      find.descendant(
        of: find.byType(UnreadableRowsNotice),
        matching: find.byType(Text),
      ),
      findsWidgets,
    );
  });

  testWidgets('a reconciliation the server took is shown as done even when '
      'its answer names a status this version does not know', (tester) async {
    final bank = _NewerServer();
    final statement = await _imported(bank);
    final line = (await bank.fetchLines(statement.id)).single;
    await _pump(tester, bank, statement);
    await tester.tap(find.byKey(ValueKey('bank-line-tile-${line.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bank-out-confirm')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Reconciled with a recorded payment'),
      findsOneWidget,
      reason: 'the list is read again and shows the written state',
    );
    expect(find.textContaining('could not be'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
