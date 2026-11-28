// SPDX-License-Identifier: AGPL-3.0-or-later
// #4512 — the expense sheet offers the business's own categories, in its order, without the retired ones, in the business's words for a
// category it renamed or added, and files the expense under the one picked, by its code.
import 'package:deskilo/features/money/providers/expense_category_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/screens/money_screen.dart' show pumpMoney;
import '../../helpers/screens/supply_expense.dart' show openExpenseSheet;

Future<void> _own(InMemoryExpenseCategories repo) async {
  final cleaning = await repo.save('ws-1', label: 'Cleaning', requestId: 'r1');
  final supplies = (await repo.categories('ws-1')).firstWhere((c) => c.code == 'supplies');
  await repo.setRetired('ws-1', supplies.id, retired: true, requestId: 'r2');
  expect(cleaning.builtIn, isFalse);
}

void main() {
  testWidgets('the sheet offers the active categories, the business\'s own words, and files under the one picked', (tester) async {
    final money = FakeMoneyRepository();
    final categories = InMemoryExpenseCategories();
    await _own(categories);
    await pumpMoney(tester, money: money, expenseCategories: categories);
    await openExpenseSheet(tester);
    final picker = find.byKey(const ValueKey('expense-sheet-money-expense-category-label'));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.text('Supplies'), findsNothing, reason: 'a retired category is not offered');
    expect(find.text('Scheduled expenses'), findsNothing);
    expect(find.text('Cleaning'), findsOneWidget);
    expect(find.text('Coffee & kitchen'), findsWidgets);

    await tester.tap(find.text('Cleaning').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '12');
    await tester.ensureVisible(find.text('Submit for confirmation'));
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(money.submittedExpenses.single.category, startsWith('c_'), reason: 'the code of the category, which the server resolves to its record');
    expect(money.submittedExpenses.single.amountCents, 1200);
  });
}
