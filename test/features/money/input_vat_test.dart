// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — input VAT. A VAT-registered space with `inputVat` on asks an
// expense for the VAT it carried and the deductible share, and sends
// both; with the flag off it asks nothing. A share outside 0..100 keeps
// the sheet open. On the return, the deductible VAT is a line of its own
// that the rate boxes leave out and each form's input box carries; the
// declarations screen names it and says what is left to pay, or to claim.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/application/submit_expense.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import 'money_screen_test.dart' show pumpMoney;
import 'supply_expense_test.dart' show openExpenseSheet;

const _input = VatDeclarationLine(
  percent: 20,
  category: 'S',
  grossCents: 23000,
  netCents: 20000,
  vatCents: 3000,
  invoiceCount: 2,
  direction: 'input',
);

const _sale = VatDeclarationLine(
  percent: 20,
  category: 'S',
  grossCents: 12000,
  netCents: 10000,
  vatCents: 2000,
  invoiceCount: 1,
);

FakeWorkspaceRepository _registered({bool inputVat = true}) {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  final ws = workspace.workspaces[0];
  workspace.workspaces[0] = ws.copyWith(
    vatRegime: 'vat_registered',
    featureFlags: {...ws.featureFlags, 'inputVat': inputVat},
  );
  return workspace;
}

FakeMoneyRepository _withRates() => FakeMoneyRepository()
  ..vatRates = const [
    VatRate(id: 'std', label: 'Standard', percent: 20, isDefault: true),
    VatRate(id: 'red', label: 'Reduced', percent: 10),
  ];

void main() {
  testWidgets('an expense states its VAT and the deductible share', (
    tester,
  ) async {
    final money = await pumpMoney(
      tester,
      money: _withRates(),
      workspace: _registered(),
    );
    await openExpenseSheet(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '120');
    await tester.tap(find.byKey(const ValueKey('expense-vat-rate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 %').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('expense-vat-deductible')),
        matching: find.byType(TextField),
      ),
      '50',
    );
    await tester.ensureVisible(find.text('Submit for confirmation'));
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(money.submittedExpenses.single.amountCents, 12000);
    expect(money.submittedExpenseVat.single, {
      'percent': 20.0,
      'deductible_pct': 50.0,
    });
  });

  testWidgets('with input VAT off, the expense asks for no VAT', (
    tester,
  ) async {
    await pumpMoney(
      tester,
      money: _withRates(),
      workspace: _registered(inputVat: false),
    );
    await openExpenseSheet(tester);
    expect(find.byKey(const ValueKey('expense-vat-rate')), findsNothing);
  });

  test('a share outside 0..100 is refused before anything is sent', () {
    const draft = ExpenseDraft(
      amount: '12',
      category: 'other',
      vatPercent: 20,
      deductible: '150',
    );
    expect(expenseOutcome(draft), ExpenseOutcome.invalidDeductible);
    expect(
      expenseOutcome(
        const ExpenseDraft(amount: '12', category: 'other', deductible: 'x'),
      ),
      ExpenseOutcome.submitted,
      reason: 'without a VAT rate the share is not asked',
    );
  });

  test('the deductible VAT has its own box, apart from the rates', () {
    final fr = vatFormBoxes('FR', const [_sale, _input]);
    expect(fr.singleWhere((b) => b.code == '08').vatCents, 2000);
    expect(fr.singleWhere((b) => b.code == '20').vatCents, 3000);
    final de = vatFormBoxes('DE', const [
      VatDeclarationLine(
        percent: 19,
        grossCents: 11900,
        netCents: 10000,
        vatCents: 1900,
        invoiceCount: 1,
      ),
      _input,
    ]);
    expect(de.singleWhere((b) => b.code == 'Kz 81').vatCents, 1900);
    expect(de.singleWhere((b) => b.code == 'Kz 66').vatCents, 3000);
    int vat(String country, String code) => vatFormBoxes(
      country,
      const [_input],
    ).singleWhere((b) => b.code == code).vatCents;
    expect(vat('GB', 'Box 4'), 3000);
    expect(vat('CH', '400'), 3000);
    expect(vat('CA', '106'), 3000);
    final line = VatDeclarationLine.fromJson(_input.toJson());
    expect(line.isInput, isTrue);
    expect(VatDeclarationLine.fromJson(_sale.toJson()).isInput, isFalse);
  });

  testWidgets('the screen names the deductible VAT and the credit', (
    tester,
  ) async {
    final money = FakeMoneyRepository();
    money.vatDeclarations.add(
      VatDeclaration(
        id: 'sep',
        workspaceId: 'ws-1',
        periodStart: DateTime(2026, 9),
        periodEnd: DateTime(2026, 9, 30),
        status: 'prepared',
        lines: const [_sale, _input],
        totalNetCents: 10000,
        totalVatCents: -1000,
        currency: 'EUR',
        invoiceCount: 1,
        createdAt: DateTime.utc(2026, 10, 2),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          money: money,
          workspace: _registered(),
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(context).push('/vat-declarations'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Deductible VAT · 20 %'), findsOneWidget);
    expect(find.byKey(const ValueKey('vat-decl-balance-sep')), findsOneWidget);
    expect(find.textContaining('VAT credit: 10 EUR'), findsOneWidget);
  });
}
