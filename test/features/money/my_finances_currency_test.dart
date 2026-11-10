// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3599 — Me › Finances beside businesses in different countries: two
// currencies that share a symbol are told apart by their code, only the
// currency of a late invoice is marked late, and a credit a business holds
// for me is said apart from what I owe.
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/my_finances_screen.dart' show invoice, show;

Text _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key)));

void main() {
  testWidgets('two dollars are two currencies: each total names its code', (
    tester,
  ) async {
    await show(
      tester,
      FinanceOverview(
        invoices: [
          invoice('us', ws: 'Austin Desk', currency: 'USD', total: 12000),
          invoice('ca', ws: 'Toronto Studio', currency: 'CAD', total: 12000),
        ],
      ),
    );
    final usd = _text(tester, 'finances-to-pay-USD').data!;
    final cad = _text(tester, 'finances-to-pay-CAD').data!;
    expect(usd, contains('USD'));
    expect(cad, contains('CAD'));
    expect(usd, isNot(cad), reason: 'the same amount, two currencies');
    expect(
      find.textContaining(r'$'),
      findsNothing,
      reason: 'a dollar sign names seven currencies',
    );
  });

  testWidgets('a symbol one currency carries alone stays', (tester) async {
    await show(
      tester,
      FinanceOverview(
        invoices: [
          invoice('eu', total: 12000),
          invoice('uk', ws: 'London', currency: 'GBP', total: 5000),
        ],
      ),
    );
    expect(_text(tester, 'finances-to-pay-EUR').data, contains('€'));
    expect(_text(tester, 'finances-to-pay-GBP').data, contains('£'));
  });

  testWidgets('only the total of the late currency is marked late', (
    tester,
  ) async {
    await show(
      tester,
      FinanceOverview(
        invoices: [
          invoice('late', due: DateTime(2020)),
          invoice('fine', ws: 'London', currency: 'GBP', due: DateTime(2099)),
        ],
      ),
    );
    final error = Theme.of(
      tester.element(find.byKey(const ValueKey('finances-summary'))),
    ).colorScheme.error;
    expect(_text(tester, 'finances-to-pay-EUR').style?.color, error);
    expect(_text(tester, 'finances-to-pay-GBP').style?.color, isNot(error));
  });

  testWidgets('a credit of another business is said apart, never taken off', (
    tester,
  ) async {
    await show(
      tester,
      FinanceOverview(
        invoices: [
          invoice('a', ws: 'Studio A', total: 40000),
          invoice('c', ws: 'Studio B', total: -2000, due: DateTime(2020)),
        ],
      ),
    );
    expect(_text(tester, 'finances-to-pay-EUR').data, contains('400'));
    expect(_text(tester, 'finances-credit-EUR').data, contains('20'));
    expect(find.text('Your credit'), findsOneWidget);
    expect(find.text('Credit not used yet'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('finances-overdue')),
      findsNothing,
      reason: 'a credit note is never late',
    );
  });

  testWidgets('only a credit open: nothing to pay is claimed', (tester) async {
    await show(tester, FinanceOverview(invoices: [invoice('c', total: -2000)]));
    expect(find.byKey(const ValueKey('finances-to-pay-EUR')), findsNothing);
    expect(find.byKey(const ValueKey('finances-credit-EUR')), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-invoice-c')), findsOneWidget);
  });
}
