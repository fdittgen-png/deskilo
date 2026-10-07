// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances: what I owe and what I paid across workspaces, my payments
// and my reminders. A member's own documents only; open one goes to its
// workspace.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/presentation/screens/my_finances_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

FinanceInvoice invoice(
  String id, {
  String ws = 'Office A',
  FinanceState state = FinanceState.open,
  DateTime? due,
  int total = 10000,
  int paid = 0,
  String currency = 'EUR',
  int reminders = 0,
}) =>
    FinanceInvoice(
      id: id,
      workspaceId: 'ws-$ws',
      workspaceName: ws,
      number: 'INV-$id',
      issuedAt: DateTime.utc(2026, 9, 1),
      dueOn: due,
      totalCents: total,
      paidCents: paid,
      currency: currency,
      state: state,
      reminderCount: reminders,
    );

Future<void> show(
  WidgetTester tester,
  FinanceOverview overview, {
  String? workspaceId,
  FakeWorkspaceRepository? workspace,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeAccountActivityRepository()..financeOverview = overview;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        accountActivity: repo,
        workspace: workspace,
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MyFinancesScreen(workspaceId: workspaceId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('what remains per currency, and which invoice counts as owed', () {
    final o = FinanceOverview(invoices: [
      invoice('1'),
      invoice('2', state: FinanceState.partiallyPaid, total: 10000, paid: 4000),
      invoice('3', currency: 'CHF', total: 500),
      invoice('4', state: FinanceState.paid),
      invoice('5', state: FinanceState.refunded),
    ]);
    expect(o.outstanding.map((i) => i.id).toSet(), {'1', '2', '3'});
    expect(o.paid.map((i) => i.id).toSet(), {'4', '5'});
    expect(o.owedByCurrency, {'EUR': 16000, 'CHF': 500});
  });

  testWidgets('outstanding leads: the total to pay, the overdue count and '
      'one card per invoice', (tester) async {
    await show(
      tester,
      FinanceOverview(invoices: [
        invoice('1', due: DateTime(2020, 1, 1)),
        invoice('2', ws: 'Office B', due: DateTime(2099, 1, 1)),
        invoice('9', state: FinanceState.paid),
      ]),
    );
    expect(find.byKey(const ValueKey('finances-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-overdue')), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-invoice-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-invoice-2')), findsOneWidget);
    // a settled invoice is not on this face
    expect(find.byKey(const ValueKey('finances-invoice-9')), findsNothing);
  });

  testWidgets('nothing owed says so; paid lists the settled ones; reminders '
      'list what was received', (tester) async {
    await show(
      tester,
      FinanceOverview(
        invoices: [invoice('9', state: FinanceState.paid)],
        reminders: [
          FinanceReminder(
            id: 'r1',
            invoiceId: '9',
            invoiceNumber: 'INV-9',
            workspaceName: 'Office A',
            sentAt: DateTime.utc(2026, 9, 20),
            level: 2,
            automatic: true,
          ),
        ],
      ),
    );
    expect(find.byKey(const ValueKey('finances-outstanding-empty')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('finances-tab-paid')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('finances-invoice-9')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('finances-tab-reminders')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('finances-reminder-r1')), findsOneWidget);
  });

  testWidgets('a failed read offers a retry, never an empty list posing as '
      '"nothing owed"', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          auth: FakeAuthRepository.signedIn(),
          accountActivity: FakeAccountActivityRepository()..unavailable = true,
        ),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MyFinancesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('finances-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-outstanding-empty')), findsNothing);
  });
}
