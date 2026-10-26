// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2360 — the Swiss acquisition tax (Bezugsteuer, art. 45 MWSTG) and the
// supplies opted for (art. 22). A Swiss space's expense says it was bought
// from a supplier abroad: its amount is then the base, the sheet shows the
// tax owed and the share deducted (the server's rounding), and the RPC is
// sent `acquisition`. A one-off expense and a scheduled one ask it alike; a
// space whose return has no acquisition box is never asked. On the
// declarations screen the tax owed is named; a stored line keeps the part
// of its base that was opted for.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/money_screen.dart' show pumpMoney;
import '../../helpers/screens/supply_expense.dart' show openExpenseSheet;

FakeWorkspaceRepository _space(String country) {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  final ws = workspace.workspaces[0];
  workspace.workspaces[0] = ws.copyWith(
    countryCode: country,
    vatRegime: 'vat_registered',
    featureFlags: {...ws.featureFlags, 'inputVat': true},
  );
  return workspace;
}

FakeMoneyRepository _withRates() => FakeMoneyRepository()
  ..vatRates = const [
    VatRate(id: 'std', label: 'Normal', percent: 8.1, isDefault: true),
    VatRate(id: 'red', label: 'Reduziert', percent: 2.6),
  ];

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _pickRate(WidgetTester tester, String prefix) async {
  await _tapKey(tester, '$prefix-vat-rate');
  await tester.tap(find.text('8.1 %').last);
  await tester.pumpAndSettle();
}

const _opted = VatDeclarationLine(
  percent: 8.1,
  category: 'S',
  grossCents: 17296,
  netCents: 16000,
  vatCents: 1296,
  invoiceCount: 2,
  optedNetCents: 10000,
);

const _acquired = VatDeclarationLine(
  percent: 8.1,
  category: vatAcquisitionCategory,
  grossCents: 12972,
  netCents: 12000,
  vatCents: 972,
  invoiceCount: 2,
);

void main() {
  testWidgets('a Swiss expense bought abroad says so, and the sheet shows '
      'the tax owed and the share deducted', (tester) async {
    final money = await pumpMoney(
      tester,
      money: _withRates(),
      workspace: _space('CH'),
    );
    await openExpenseSheet(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '100');
    await _pickRate(tester, 'expense');
    await _tapKey(tester, 'expense-vat-acquisition');
    expect(
      find.textContaining(
        RegExp(r'Acquisition tax owed: .*8\.10 · deductible: .*8\.10'),
      ),
      findsOneWidget,
      reason: '8.1 % of 100.00 is owed, and all of it deducted',
    );
    await tester.ensureVisible(find.text('Submit for confirmation'));
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(money.submittedExpenses.single.amountCents, 10000);
    expect(money.submittedExpenseVat.single, {
      'percent': 8.1,
      'deductible_pct': 100.0,
      'acquisition': true,
    });
  });

  testWidgets('switched back off, the expense is an ordinary one', (
    tester,
  ) async {
    final money = await pumpMoney(
      tester,
      money: _withRates(),
      workspace: _space('CH'),
    );
    await openExpenseSheet(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '108.10');
    await _pickRate(tester, 'expense');
    await _tapKey(tester, 'expense-vat-acquisition');
    await _tapKey(tester, 'expense-vat-acquisition');
    expect(find.textContaining('Acquisition tax owed: '), findsNothing);
    await tester.ensureVisible(find.text('Submit for confirmation'));
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(money.submittedExpenseVat.single, {
      'percent': 8.1,
      'deductible_pct': 100.0,
    });
  });

  testWidgets('a space whose return has no acquisition box is not asked', (
    tester,
  ) async {
    await pumpMoney(tester, money: _withRates(), workspace: _space('FR'));
    await openExpenseSheet(tester);
    await _pickRate(tester, 'expense');
    expect(_key('expense-vat-asset'), findsOneWidget);
    expect(_key('expense-vat-acquisition'), findsNothing);
  });

  testWidgets('a scheduled Swiss expense bought abroad says so for every '
      'occurrence', (tester) async {
    final money = await pumpMoney(
      tester,
      money: _withRates(),
      workspace: _space('CH'),
    );
    await tester.scrollUntilVisible(
      _key('scheduled-expenses-button'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(_key('scheduled-expenses-button'));
    await tester.pumpAndSettle();
    await tester.tap(_key('schedule-new'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('schedule-title'), 'Software');
    await tester.enterText(_key('schedule-amount'), '60');
    await _pickRate(tester, 'schedule');
    await _tapKey(tester, 'schedule-vat-acquisition');
    await _tapKey(tester, 'schedule-submit');

    final id = money.expenseSchedules.single.id;
    expect(money.expenseScheduleVat[id], {
      'percent': 8.1,
      'deductible_pct': 100.0,
      'acquisition': true,
    });
  });

  test('a stored line keeps the part of its base that was opted for', () {
    final back = VatDeclarationLine.fromJson(_opted.toJson());
    expect(back.optedNetCents, 10000);
    expect(_opted.toJson()['opted_net_cents'], 10000);
    expect(
      VatDeclarationLine.fromJson(_acquired.toJson()).toJson(),
      isNot(contains('opted_net_cents')),
    );
    expect(
      VatDeclarationLine.fromJson(_acquired.toJson()).isAcquisition,
      isTrue,
    );
  });

  testWidgets('the declarations screen names the acquisition tax', (
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
        lines: const [_opted, _acquired],
        totalNetCents: 16000,
        totalVatCents: 2268,
        currency: 'CHF',
        invoiceCount: 2,
        createdAt: DateTime.utc(2026, 10, 2),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(money: money, workspace: _space('CH')),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(context).push('/vat-declarations'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Acquisition tax · 8.1 %'), findsOneWidget);
  });
}
