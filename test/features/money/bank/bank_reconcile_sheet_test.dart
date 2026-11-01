// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — money out in the work list: a movement out reconciles the
// payment reported as made of its amount, through its dialog, and the
// payment is no longer a candidate; a reader who may match but not
// reconcile sees the movement and no door. A reconciled movement is undone
// through its dialog, which refuses to send without a reason: the movement
// is open again, the payment a candidate again, the undoing on record once.
import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/presentation/widgets/bank_lines_sheet.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeBankStatementRepository bank;

  setUp(() {
    bank = FakeBankStatementRepository(
      money: FakeMoneyRepository(),
      today: DateTime.utc(2026, 10, 26),
    );
  });

  Future<void> pump(WidgetTester tester, Widget body) async {
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
          home: Scaffold(body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('money out reconciles the payment reported as made; a reader '
      'without the rights sees the list and no door', (tester) async {
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
    final statement = (await bank.fetchStatements('ws-1'))
        .singleWhere((s) => s.id == result.statementId);
    final line = (await bank.fetchLines(statement.id)).single;

    await pump(
      tester,
      BankLinesView(
        workspaceId: 'ws-1',
        statement: statement,
        canMatch: true,
        canReconcile: false,
      ),
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(ValueKey('bank-line-tile-${line.id}')))
          .onTap,
      isNull,
      reason: 'reconciling needs recordOutgoingPayments',
    );

    await pump(
      tester,
      BankLinesView(
        workspaceId: 'ws-1',
        statement: statement,
        canMatch: false,
        canReconcile: true,
      ),
    );
    await tester.tap(find.byKey(ValueKey('bank-line-tile-${line.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bank-out-out-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bank-out-confirm')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Reconciled with a recorded payment'),
      findsOneWidget,
    );
    expect(
      (await bank.fetchLines(statement.id)).single.status,
      BankLineStatus.reconciled,
    );
    expect(bank.reportedPayments, isEmpty);
  });

  testWidgets('a reconciled movement out is undone with a reason, once; a '
      'reader without the right that reconciles has no door', (tester) async {
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
      sourceSha256: 'e' * 64,
      fileName: 'o.xml',
    );
    final statement = (await bank.fetchStatements('ws-1'))
        .singleWhere((s) => s.id == result.statementId);
    final line = (await bank.fetchLines(statement.id)).single;
    await bank.reconcileOut(line.id, outgoingPaymentId: 'out-1');
    final tile = find.byKey(ValueKey('bank-line-tile-${line.id}'));

    await pump(
      tester,
      BankLinesView(
        workspaceId: 'ws-1',
        statement: statement,
        canMatch: true,
        canReconcile: false,
      ),
    );
    expect(
      tester.widget<ListTile>(tile).onTap,
      isNull,
      reason: 'undoing needs recordOutgoingPayments, as reconciling does',
    );

    await pump(
      tester,
      BankLinesView(
        workspaceId: 'ws-1',
        statement: statement,
        canMatch: false,
        canReconcile: true,
      ),
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bank-undo-confirm')));
    await tester.pumpAndSettle();
    expect(
      find.text('Say why the reconciliation is undone.'),
      findsOneWidget,
      reason: 'no reason, nothing sent',
    );
    expect(bank.unreconciliations, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('bank-undo-reason')),
      'The other reimbursement of 15',
    );
    await tester.tap(find.byKey(const ValueKey('bank-undo-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Undo this reconciliation?'), findsNothing);
    final after = (await bank.fetchLines(statement.id)).single;
    expect(after.status, BankLineStatus.open);
    expect(after.outgoingCandidates.map((c) => c.id), [
      'out-1',
    ], reason: 'the payment is reported again, a candidate again');
    expect(bank.unreconciliations.values.single, (
      lineId: line.id,
      paymentId: 'out-1',
      reason: 'The other reimbursement of 15',
    ));
    expect(
      tester.widget<ListTile>(tile).onTap,
      isNotNull,
      reason: 'open money out reconciles again',
    );
  });
}
