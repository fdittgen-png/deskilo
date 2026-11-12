// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3403/#3447 -- "bought from abroad" is offered where today's return has a
// box for the tax it then owes, and that is asked of the workspace's tax
// reference WHEN THE SHEET IS DRAWN. A sheet opened before the context was
// ready shows the option once it is, in the same sheet, without reopening --
// the one-off expense and the scheduled one alike.
import 'package:deskilo/app/app.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/money_screen.dart' show pumpMoney;
import '../../helpers/screens/supply_expense.dart' show openExpenseSheet;
import '../../helpers/test_workspace_context.dart';

FakeWorkspaceRepository _swiss() {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  final ws = workspace.workspaces[0];
  workspace.workspaces[0] = ws.copyWith(
    countryCode: 'CH',
    vatRegime: 'vat_registered',
    featureFlags: {...ws.featureFlags, 'inputVat': true},
  );
  return workspace;
}

FakeMoneyRepository _withRates() => FakeMoneyRepository()
  ..vatRates = const [
    VatRate(id: 'std', label: 'Normal', percent: 8.1, isDefault: true),
  ];

Finder _key(String key) => find.byKey(ValueKey(key));

void _ready(WidgetTester tester, {required bool ready}) =>
    ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
        .read(testContextReady.notifier)
        .set(ready: ready);

Future<void> _pickRate(WidgetTester tester, String prefix) async {
  await tester.ensureVisible(_key('$prefix-vat-rate'));
  await tester.tap(_key('$prefix-vat-rate'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('8.1%').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the expense sheet offers "bought from abroad" once the context '
      'is ready, without reopening', (tester) async {
    await pumpMoney(
      tester,
      money: _withRates(),
      workspace: _swiss(),
      extraOverrides: [testSwitchableReadyWorkspaceContext()],
    );
    _ready(tester, ready: false);
    await tester.pump();
    await openExpenseSheet(tester);
    await _pickRate(tester, 'expense');
    expect(_key('expense-vat-asset'), findsOneWidget);
    expect(_key('expense-vat-acquisition'), findsNothing);

    _ready(tester, ready: true);
    await tester.pumpAndSettle();
    expect(_key('expense-vat-acquisition'), findsOneWidget);
  });

  testWidgets('the scheduled expense sheet does the same', (tester) async {
    await pumpMoney(
      tester,
      money: _withRates(),
      workspace: _swiss(),
      extraOverrides: [testSwitchableReadyWorkspaceContext()],
    );
    _ready(tester, ready: false);
    await tester.pump();
    await tester.scrollUntilVisible(
      _key('scheduled-expenses-button'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(_key('scheduled-expenses-button'));
    await tester.pumpAndSettle();
    await tester.tap(_key('schedule-new'));
    await tester.pumpAndSettle();
    await _pickRate(tester, 'schedule');
    expect(_key('schedule-vat-asset'), findsOneWidget);
    expect(_key('schedule-vat-acquisition'), findsNothing);

    _ready(tester, ready: true);
    await tester.pumpAndSettle();
    expect(_key('schedule-vat-acquisition'), findsOneWidget);
  });
}
