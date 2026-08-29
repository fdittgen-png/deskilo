// SPDX-License-Identifier: 0BSD
//
// #731 — an expense can be a SUPPLY for the space: the sheet asks what
// it is, how many and what a consumption will cost, and sends it with
// the expense; the shelf shows its stock; an empty shelf cannot be
// consumed.
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import 'money_screen_test.dart' show pumpMoney;

Future<void> openExpenseSheet(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Submit an expense'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Submit an expense'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a supply expense carries item, quantity and unit price',
      (tester) async {
    final money = await pumpMoney(tester);
    await openExpenseSheet(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '12.00');
    await tester.tap(find.byKey(const ValueKey('expense-supply-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('expense-supply-name')), 'Capsules');
    await tester.enterText(
        find.byKey(const ValueKey('expense-supply-quantity')), '10');
    await tester.pumpAndSettle();
    // Unit price prefilled from amount ÷ quantity.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('expense-supply-unit')))
          .controller!
          .text,
      '1.20',
    );
    await tester.ensureVisible(find.text('Submit for confirmation'));
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    final expense = money.submittedExpenses.single;
    expect(expense.amountCents, 1200);
    expect(expense.supply, {
      'name': 'Capsules',
      'quantity': 10,
      'unit_price_cents': 120,
    });
  });

  testWidgets('a plain expense sends no supply', (tester) async {
    final money = await pumpMoney(tester);
    await openExpenseSheet(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '5');
    await tester.ensureVisible(find.text('Submit for confirmation'));
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();
    expect(money.submittedExpenses.single.supply, isNull);
  });

  testWidgets('the consumption sheet shows the shelf and refuses an overdraw',
      (tester) async {
    final money = FakeMoneyRepository();
    money.services
      ..clear()
      ..addAll(const [
        ServiceItem(
          id: 'svc-capsules',
          workspaceId: 'ws-1',
          name: 'Capsules',
          priceCents: 120,
          active: true,
          stock: 2,
        ),
        ServiceItem(
          id: 'svc-bags',
          workspaceId: 'ws-1',
          name: 'Vacuum bags',
          priceCents: 300,
          active: true,
          stock: 0,
        ),
      ]);
    await pumpMoney(tester, money: money);
    await tester.scrollUntilVisible(
      find.text('Add consumption'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add consumption'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 in stock'), findsOneWidget);

    // Quantity 3 of a shelf of 2: the submit is disabled.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    final submit = tester.widget<FilledButton>(
        find.byKey(const ValueKey('consumption-submit')));
    expect(submit.onPressed, isNull);

    // The empty shelf is offered greyed, not hidden.
    await tester.tap(find.byType(DropdownButtonFormField<ServiceItem>));
    await tester.pumpAndSettle();
    expect(find.textContaining('Out of stock'), findsWidgets);
  });
}
