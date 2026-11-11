// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (ADR 0035): what I owe is visible from Me › Home without opening a
// workspace — the total, the overdue count — and one tap opens Me › Finances.
// With nothing to pay there is no card at all.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/my_finances_screen.dart' show invoice;
import 'me_app.dart';

void main() {
  testWidgets('the home shows what I owe and opens Finances', (tester) async {
    final repo = FakeAccountActivityRepository()
      ..financeOverview = FinanceOverview(
        invoices: [
          invoice('a', total: 12000, due: DateTime(2000)),
          invoice('b', ws: 'Office B', total: 3000, due: DateTime(2999)),
        ],
      );
    final router = await pumpMeApp(
      tester,
      workspace: twoSpaces(),
      accountActivity: repo,
    );
    await goTo(tester, router, '/me');
    expect(
      find.byKey(const ValueKey('me-home-finance-glance')),
      findsOneWidget,
    );
    // #2552: the amount is private, masked until revealed.
    expect(find.textContaining('150'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('me-home-finance-glance-amount-EUR')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('150'), findsOneWidget, reason: '120 + 30');
    expect(router.state.uri.path, '/me', reason: 'revealing is not opening');
    expect(find.text('1 overdue'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('me-home-finance-glance')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/account-activity');
  });

  // #3281/#3286: the card is a named button, not an anonymous group.
  testWidgets('the To pay card is a named button', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = FakeAccountActivityRepository()
      ..financeOverview = FinanceOverview(
        invoices: [invoice('b', ws: 'Office B', total: 3000, due: DateTime(2999))],
      );
    final router = await pumpMeApp(
      tester,
      workspace: twoSpaces(),
      accountActivity: repo,
    );
    await goTo(tester, router, '/me');
    final node = tester.getSemantics(
      find.byKey(const ValueKey('me-home-tab-finance-glance-owed')),
    );
    expect(node.label, contains('To pay: open my finances'));
    expect(node.flagsCollection.isButton, isTrue);
    expect(
      find.byKey(const ValueKey('me-home-finance-glance-amount-EUR')),
      findsOneWidget,
      reason: 'the amount keeps its own reveal target',
    );
    handle.dispose();
  });

  testWidgets('nothing to pay, no card', (tester) async {
    final repo = FakeAccountActivityRepository()
      ..financeOverview = FinanceOverview(
        invoices: [invoice('a', state: FinanceState.paid)],
      );
    final router = await pumpMeApp(
      tester,
      workspace: twoSpaces(),
      accountActivity: repo,
    );
    await goTo(tester, router, '/me');
    expect(find.byKey(const ValueKey('me-home-finance-glance')), findsNothing);
  });

  // #3682 — paid, the business has not confirmed yet: neither owed nor late.
  testWidgets('a payment being validated is neither in the total nor '
      'overdue', (tester) async {
    final repo = FakeAccountActivityRepository()
      ..financeOverview = FinanceOverview(
        invoices: [
          invoice(
            'v',
            total: 12000,
            state: FinanceState.awaitingValidation,
            due: DateTime(2000),
          ),
          invoice('b', ws: 'Office B', total: 3000, due: DateTime(2999)),
        ],
      );
    final router = await pumpMeApp(
      tester,
      workspace: twoSpaces(),
      accountActivity: repo,
    );
    await goTo(tester, router, '/me');
    await tester.tap(
      find.byKey(const ValueKey('me-home-finance-glance-amount-EUR')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('30'), findsOneWidget);
    expect(find.textContaining('150'), findsNothing);
    expect(find.text('1 overdue'), findsNothing);
  });

  testWidgets('only a payment being validated: no card', (tester) async {
    final repo = FakeAccountActivityRepository()
      ..financeOverview = FinanceOverview(
        invoices: [
          invoice('v', state: FinanceState.awaitingValidation, due: DateTime(2000)),
        ],
      );
    final router = await pumpMeApp(
      tester,
      workspace: twoSpaces(),
      accountActivity: repo,
    );
    await goTo(tester, router, '/me');
    expect(find.byKey(const ValueKey('me-home-finance-glance')), findsNothing);
  });

  testWidgets('the home total ignores a development space; its invoice opens '
      'in that development space', (tester) async {
    final spaces = twoSpaces();
    spaces.workspaces[1] = spaces.workspaces[1].copyWith(environment: 'dev');
    spaces.workspaces[0] = spaces.workspaces[0].copyWith(environment: 'prod');
    final repo = FakeAccountActivityRepository()
      ..financeOverview = FinanceOverview(
        invoices: [
          FinanceInvoice(
            id: 'dev-inv',
            workspaceId: 'ws-2',
            workspaceName: 'Second Space',
            number: 'D-1',
            issuedAt: DateTime.utc(2026, 9),
            totalCents: 50000,
            paidCents: 0,
            currency: 'EUR',
            state: FinanceState.open,
          ),
        ],
      );
    final router = await pumpMeApp(
      tester,
      workspace: spaces,
      accountActivity: repo,
    );
    await goTo(tester, router, '/me');
    expect(find.byKey(const ValueKey('me-home-finance-glance')), findsNothing,
        reason: 'only test data is owed: nothing to pay in Me');

    await goTo(tester, router, '/account-activity');
    await tester.tap(find.byKey(const ValueKey('finances-open-dev-inv')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/money');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(container.read(activeWorkspaceIdProvider).value, 'ws-2',
        reason: 'the invoice opens in its own (development) space');
  });
}
