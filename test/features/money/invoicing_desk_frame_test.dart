// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- the desk layout as the real app draws it. Every route sits
// in the app's frame (AppFrame), which narrows the screen and rewrites the
// window size; a screen pumped on its own never sees that. Here /invoices
// is reached through the app itself at a 1440 x 900 window: the frame gives
// it the wide width, the customer table shows, and an invoice opens in the
// panel BESIDE the list, which keeps its table.
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('at 1440 x 900 an invoice opens beside the list, whose table '
      'stays', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final money = FakeMoneyRepository();
    final id = await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: kTestPeriod,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(money: money),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/invoices');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('invoicing-home')), findsOneWidget);
    // The customer list is the table, under its header.
    expect(find.text('CUSTOMER'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('invoicing-view')),
        matching: find.text('Invoices'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('invoicing-row-$id')));
    await tester.pumpAndSettle();

    final panel = find.byKey(ValueKey('invoicing-panel-$id'));
    expect(panel, findsOneWidget, reason: 'a desk keeps the invoice beside');
    final list = find.byKey(const ValueKey('invoicing-home'));
    expect(
      tester.getTopLeft(panel).dx,
      greaterThan(tester.getTopRight(list).dx - 1),
      reason: 'the panel sits to the right of the list',
    );
    // Beside the panel, the list is still a table.
    expect(find.text('INVOICE'), findsWidgets);
  });
}
