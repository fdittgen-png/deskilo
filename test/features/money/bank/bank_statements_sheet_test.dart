// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — the bank statements as a person meets them: importing the
// camt.054 file (picked, its format recognised, read) lists the statement
// and says what it added; importing it again says nothing was added; the
// movements whose QR or RF reference names their invoice are confirmed in
// one press and then read "Settles <number>", the third stays to match; a
// movement that resembles another statement's is declared a duplicate
// through its review.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/presentation/widgets/bank_lines_sheet.dart';
import 'package:deskilo/features/money/presentation/widgets/bank_statements_sheet.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(String number, int total, String member) => Invoice(
  id: 'id-$number',
  workspaceId: 'ws-1',
  memberId: member,
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

final _camt = File(
  'test/features/money/fixtures/bank/camt054_notification.xml',
).readAsBytesSync();

void main() {
  late FakeMoneyRepository money;
  late FakeBankStatementRepository bank;

  setUp(() {
    money = FakeMoneyRepository()
      ..invoices.addAll([
        _invoice('21000000000313947143000901', 12000, 'm1'),
        _invoice('539007547034', 8050, 'm2'),
      ]);
    bank = FakeBankStatementRepository(money: money, today: DateTime.utc(2026, 10, 26));
  });

  Future<void> pump(WidgetTester tester, Widget body) async {
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bankStatementRepositoryProvider.overrideWithValue(bank),
        invoicesProvider.overrideWith((ref) async => [...money.invoices]),
        invoiceMatchesProvider.overrideWith((ref) async => {...money.invoiceMatchesStore}),
        filePickerProvider.overrideWithValue(
          (_) async => XFile.fromData(Uint8List.fromList(_camt), name: 'notification.xml'),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: body),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('importing a file lists it and says what it added; the same '
      'file again adds nothing', (tester) async {
    await pump(tester, const BankStatementsView(
      workspaceId: 'ws-1',
      currency: 'CHF',
      canMatch: true,
      canReconcile: true,
    ));
    expect(find.byKey(const ValueKey('bank-statements-empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bank-import')));
    await tester.pumpAndSettle();
    // The format is recognised and already chosen.
    final format = tester.widget<RadioGroup<BankFileFormat>>(
      find.byKey(const ValueKey('bank-format-group')),
    );
    expect(format.groupValue, BankFileFormat.camt054);
    await tester.tap(find.byKey(const ValueKey('bank-format-read')));
    await tester.pumpAndSettle();
    expect(find.text('Imported: 3 new, 0 already known, 0 to review.'), findsOneWidget);
    expect(find.textContaining('CH9300762011623852957'), findsOneWidget);

    // The first notice goes, so the second one shows.
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bank-import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bank-format-read')));
    await tester.pumpAndSettle();
    expect(find.text('This file was already imported. Nothing was added.'), findsOneWidget);
    expect(await bank.fetchStatements('ws-1'), hasLength(1));
    // #2380 — the imported file is kept once, and the statement offers it.
    final stored = (await bank.fetchStatements('ws-1')).single;
    expect(bank.originals.keys, ['ws-1/${stored.sourceSha256}']);
    expect(bank.originals.values.single, _camt);
    expect(
      find.byKey(ValueKey('bank-statement-original-${stored.id}')),
      findsOneWidget,
    );
  });

  testWidgets('the reference matches are confirmed in one press; the third '
      'movement stays to match', (tester) async {
    final result = await bank.importStatement(
      'ws-1',
      statement: _statement(),
      sourceSha256: 'a' * 64,
      fileName: 'n.xml',
    );
    final statement = (await bank.fetchStatements('ws-1')).single;
    expect(statement.id, result.statementId);
    await pump(tester, BankLinesView(
      workspaceId: 'ws-1',
      statement: statement,
      canMatch: true,
      canReconcile: true,
    ));
    expect(find.text('Confirm 2 matches by reference'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bank-confirm-references')));
    await tester.pumpAndSettle();
    expect(find.text('2 payments matched.'), findsOneWidget);
    expect(find.textContaining('Settles 21000000000313947143000901'), findsOneWidget);
    expect(find.textContaining('Settles 539007547034'), findsOneWidget);
    expect(find.textContaining('To match'), findsOneWidget);
    expect(find.byKey(const ValueKey('bank-confirm-references')), findsNothing);
  });

  testWidgets('a movement that resembles another statement\'s is declared a '
      'duplicate through its review', (tester) async {
    final line = BankLine(
      position: 1,
      bookingDate: DateTime.utc(2026, 10, 20),
      valueDate: DateTime.utc(2026, 10, 20),
      amountCents: 4500,
      currency: 'CHF',
      remittance: 'Coffee',
    );
    BankStatement one(List<BankLine> lines) => BankStatement(
      format: BankFileFormat.csv,
      account: 'CH9300762011623852957',
      currency: 'CHF',
      lines: lines,
    );
    await bank.importStatement('ws-1', statement: one([line]), sourceSha256: 'b' * 64, fileName: 'a.csv');
    final second = await bank.importStatement('ws-1', statement: one([line]), sourceSha256: 'c' * 64, fileName: 'b.csv');
    expect(second.review, 1);
    final statement = (await bank.fetchStatements('ws-1'))
        .singleWhere((s) => s.id == second.statementId);
    await pump(tester, BankLinesView(
      workspaceId: 'ws-1',
      statement: statement,
      canMatch: true,
      canReconcile: true,
    ));
    expect(find.textContaining('Possibly imported already'), findsOneWidget);
    await tester.tap(find.textContaining('Possibly imported already'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bank-review-duplicate')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Duplicate'), findsOneWidget);
    final stored = (await bank.fetchLines(second.statementId)).single;
    expect(stored.status, BankLineStatus.duplicate);
  });
}

/// The camt.054 fixture's three movements as the parser reads them.
BankStatement _statement() {
  BankLine l(int n, int cents, String ref, String tx) => BankLine(
    position: n,
    bookingDate: DateTime.utc(2026, 10, 20),
    valueDate: DateTime.utc(2026, 10, 20),
    amountCents: cents,
    currency: 'CHF',
    reference: ref,
    transactionId: tx,
  );
  return BankStatement(
    format: BankFileFormat.camt054,
    account: 'CH9300762011623852957',
    currency: 'CHF',
    lines: [
      l(1, 12000, '210000000003139471430009017', 'T1'),
      l(2, 8050, 'RF18539007547034', 'T2'),
      l(3, 3000, '', 'T3'),
    ],
  );
}
