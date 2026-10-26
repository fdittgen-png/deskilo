// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2577 C1 — the purchase and the sales side each have a page, opening the
// existing sheets and screens with their own gates: a member keeps their own
// expense, a manager gets the space's doors, and a door nobody may use is
// absent rather than refused later.
import 'package:deskilo/features/money/presentation/screens/money_hubs_screen.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Set<WorkspaceFeature> features = const {},
  Set<WorkspacePermission> rights = const {},
  bool owner = true,
}) => pumpApp(
  tester,
  page,
  overrides: [
    ...standardTestOverrides(
      workspace: FakeWorkspaceRepository.withWorkspace()
        ..myMember = FakeWorkspaceRepository.withWorkspace().myMember.copyWith(
          isOwner: owner,
          isAdmin: owner,
        ),
    ),
    enabledFeaturesSyncProvider.overrideWithValue(features),
    myPermissionsProvider.overrideWithValue(rights),
  ],
);

void main() {
  testWidgets('the purchases page keeps the person\'s own expense and adds '
      'the space\'s documents only with purchases on', (tester) async {
    await _pump(tester, const PurchasesHubScreen());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('purchases-hub-own-expense')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('purchases-button')), findsNothing);

    await _pump(
      tester,
      const PurchasesHubScreen(),
      features: {WorkspaceFeature.purchases},
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchases-button')), findsOneWidget);
  });

  testWidgets('the sales page shows a door only to whoever may open it', (
    tester,
  ) async {
    await _pump(tester, const SalesHubScreen());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sales-hub-invoices')), findsOneWidget);
    expect(find.byKey(const ValueKey('sales-hub-billing')), findsNothing);
    expect(find.byKey(const ValueKey('sales-hub-services')), findsNothing);

    await _pump(
      tester,
      const SalesHubScreen(),
      features: {WorkspaceFeature.services},
      rights: {
        WorkspacePermission.manageBilling,
        WorkspacePermission.manageServices,
      },
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sales-hub-billing')), findsOneWidget);
    expect(find.byKey(const ValueKey('sales-hub-services')), findsOneWidget);
  });

  testWidgets('add purchase / expense: a member goes straight to their own '
      'expense', (tester) async {
    await _pump(tester, const PurchasesHubScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('purchases-hub-own-expense')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-purchase-me')), findsNothing);
    expect(find.byKey(const ValueKey('expense-submit')), findsOneWidget);
  });

  testWidgets('add purchase / expense for a purchase manager: who paid, then '
      'the bill form', (tester) async {
    await _pump(
      tester,
      const PurchasesHubScreen(),
      features: {WorkspaceFeature.purchases},
      rights: {WorkspacePermission.managePurchases},
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('purchases-hub-own-expense')));
    await tester.pumpAndSettle();
    for (final answer in ['me', 'unpaid', 'space']) {
      expect(find.byKey(ValueKey('add-purchase-$answer')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('add-purchase-unpaid')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-supplier')), findsOneWidget);
  });

  testWidgets('the cash page says its money is recorded, not a bank '
      'balance, and offers what is still to pay only with purchases on', (
    tester,
  ) async {
    await _pump(tester, const CashHubScreen());
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('cash-hub-recorded')), findsOneWidget);
    expect(find.byKey(const ValueKey('cash-hub-to-pay')), findsNothing);

    await _pump(
      tester,
      const CashHubScreen(),
      features: {WorkspaceFeature.purchases},
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('cash-hub-to-pay')), findsOneWidget);
  });

  testWidgets('the accounting page opens a door only with its flag on', (
    tester,
  ) async {
    await _pump(tester, const AccountingHubScreen());
    await tester.pump();
    expect(find.byKey(const ValueKey('accounting-hub')), findsOneWidget);
    for (final key in [
      'accounting-hub-export', 'accounting-hub-identity', 'accounting-hub-vat',
      'accounting-hub-vat-declarations', 'accounting-hub-sequences',
      'accounting-hub-einvoice',
    ]) {
      expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
    }

    await _pump(
      tester,
      const AccountingHubScreen(),
      features: {
        WorkspaceFeature.invoicing,
        WorkspaceFeature.vatManagement,
        WorkspaceFeature.numberSequences,
      },
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('accounting-hub-export')), findsOneWidget);
    expect(find.byKey(const ValueKey('accounting-hub-identity')), findsOneWidget);
    expect(find.byKey(const ValueKey('accounting-hub-vat')), findsOneWidget);
    expect(find.byKey(const ValueKey('accounting-hub-sequences')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('accounting-hub-vat-declarations')),
      findsNothing,
      reason: 'the declarations need their own flag',
    );
  });

  testWidgets('the accounting page shows a member only the doors of their '
      'rights; the sequences door asks its own flag', (tester) async {
    const flags = {WorkspaceFeature.invoicing, WorkspaceFeature.vatManagement};
    await _pump(tester, const AccountingHubScreen(), features: flags, owner: false);
    await tester.pump();
    expect(find.byKey(const ValueKey('accounting-hub-export')), findsNothing);
    expect(find.byKey(const ValueKey('accounting-hub-vat')), findsNothing);

    await _pump(
      tester,
      const AccountingHubScreen(),
      features: flags,
      rights: {WorkspacePermission.issueInvoices},
      owner: false,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('accounting-hub-export')), findsOneWidget);
    expect(find.byKey(const ValueKey('accounting-hub-vat')), findsNothing);
    expect(find.byKey(const ValueKey('accounting-hub-identity')), findsNothing);

    await _pump(
      tester,
      const AccountingHubScreen(),
      features: flags,
      rights: {WorkspacePermission.manageBilling},
      owner: false,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('accounting-hub-vat')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('accounting-hub-sequences')),
      findsNothing,
      reason: 'billing alone: the sequences flag is off',
    );
  });
}
