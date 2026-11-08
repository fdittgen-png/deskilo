// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 (0650) -- a matched movement in is undone from the work list: the
// door is there for whoever may match and for no one else; the dialog
// refuses to send without a reason; the movement reads recorded and the
// invoice is open again; and a match the server will not undo says why in
// words (a credit note was issued), changing nothing.
import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/presentation/widgets/bank_lines_sheet.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(String number, int total) => Invoice(
  id: 'id-$number',
  workspaceId: 'ws-1',
  memberId: 'm1',
  number: number,
  issuedAt: DateTime.utc(2026, 10, 2),
  title: number,
  lines: const [],
  totalCents: total,
  currency: 'CHF',
  memberName: 'Demo Member',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Space',
  signature: '',
);

/// A bounded settle: a sheet, a dialog and a snackbar arrive within it.
Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeMoneyRepository money;
  late FakeBankStatementRepository bank;

  setUp(() {
    money = FakeMoneyRepository()
      ..invoices.addAll([_invoice('I1', 10000), _invoice('I2', 8000)]);
    bank = FakeBankStatementRepository(
      money: money,
      today: DateTime.utc(2026, 10, 26),
    );
  });

  Future<(StoredBankStatement, StoredBankLine)> matchedLine(
    String invoice,
    String resolution,
  ) async {
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
            valueDate: DateTime.utc(2026, 10, 21),
            amountCents: 10000,
            currency: 'CHF',
            transactionId: 'T1',
          ),
        ],
      ),
      sourceSha256: 'c' * 64,
      fileName: 'm.xml',
    );
    final statement = (await bank.fetchStatements('ws-1'))
        .singleWhere((s) => s.id == result.statementId);
    final line = (await bank.fetchLines(statement.id)).single;
    await bank.matchLine(
      line.id,
      invoiceId: 'id-$invoice',
      resolution: resolution,
      note: '',
    );
    return (statement, (await bank.fetchLines(statement.id)).single);
  }

  Future<void> pump(
    WidgetTester tester,
    StoredBankStatement statement, {
    required bool canMatch,
  }) async {
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
              canMatch: canMatch,
              canReconcile: false,
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('a matched movement in is undone with a reason; only whoever '
      'may match has the door', (tester) async {
    final (statement, line) = await matchedLine('I1', 'exact');
    final tile = find.byKey(ValueKey('bank-line-tile-${line.id}'));

    await pump(tester, statement, canMatch: false);
    expect(tester.widget<ListTile>(tile).onTap, isNull,
        reason: 'undoing needs the right that matches');

    await pump(tester, statement, canMatch: true);
    expect(tester.widget<ListTile>(tile).onTap, isNotNull);
    await tester.tap(tile);
    await _settle(tester);
    expect(find.text('Undo this match?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bank-undo-confirm')));
    await _settle(tester);
    expect(find.text('Say why the match is undone.'), findsOneWidget,
        reason: 'no reason, nothing sent');
    expect(bank.unmatches, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('bank-undo-reason')),
      'Wrong invoice',
    );
    await tester.tap(find.byKey(const ValueKey('bank-undo-confirm')));
    await _settle(tester);
    expect((await bank.fetchLines(statement.id)).single.status,
        BankLineStatus.recorded);
    expect(money.invoiceMatchesStore.containsKey('id-I1'), isFalse,
        reason: 'the invoice is open again');
    expect(bank.unmatches.values.single.reason, 'Wrong invoice');
  });

  testWidgets('a match that issued a credit note says why it is not undone '
      'here, and changes nothing', (tester) async {
    money.invoices.add(_invoice('I3', 8000));
    final (statement, line) = await matchedLine('I3', 'over_credit_note');
    await pump(tester, statement, canMatch: true);

    await tester.tap(find.byKey(ValueKey('bank-line-tile-${line.id}')));
    await _settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('bank-undo-reason')),
      'Wrong invoice',
    );
    await tester.tap(find.byKey(const ValueKey('bank-undo-confirm')));
    await _settle(tester);

    expect(find.textContaining('did more than link a payment'), findsOneWidget,
        reason: 'the refusal is shown in words');
    expect((await bank.fetchLines(statement.id)).single.status,
        BankLineStatus.matched);
    expect(money.invoiceMatchesStore.containsKey('id-I3'), isTrue);
    expect(bank.unmatches, isEmpty);
  });
}
