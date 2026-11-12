// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- the desk layout as the real app draws it. Every route sits
// in the app's frame (AppFrame), which narrows the screen and rewrites the
// window size; a screen pumped on its own never sees that. Here /invoices
// is reached through the app itself: the frame gives it the wide width, the
// customer table shows, and an invoice opens in the panel BESIDE the list,
// which keeps its table. #3773 — the page asks whether the list and the
// invoice both fit (invoiceFitsBeside), not which window class it has: beside
// the desk's sidebar at 1440 (1167 px), with the rail, and at 1920; over the
// list at 1024, where the rail leaves 943.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_page.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  for (final (width, rail, beside) in [
    (1920.0, false, true),
    (1440.0, false, true),
    (1440.0, true, true),
    (1024.0, true, false),
  ]) {
  testWidgets('at ${width.toInt()} x 900${rail ? ' on the rail' : ''} an '
      'invoice opens ${beside ? 'beside the list, whose table stays' : 'over '
      'the list'}', (tester) async {
    tester.view.physicalSize = Size(width, 900);
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
        overrides: standardTestOverrides(
          money: money,
          deskRailCollapsed: InMemoryShellFlagStore(value: rail),
        ),
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
    if (!beside) {
      expect(panel, findsNothing, reason: 'the list and the invoice do not fit');
      expect(find.byType(InvoicePage), findsOneWidget);
      return;
    }
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

  test('both fit from the list\'s minimum, the rule and the panel, and not '
      'one pixel before', () {
    const both = kInvoicingListMinWidth + 1 + kInvoicingPanelWidth;
    expect(invoiceFitsBeside(both), isTrue);
    expect(invoiceFitsBeside(both - 1), isFalse);
    // The desk at 1440 with the sidebar (1167) and at 1024 with the rail (943).
    expect(invoiceFitsBeside(1167), isTrue);
    expect(invoiceFitsBeside(943), isFalse);
  });
}
