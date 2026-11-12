// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3789 (from the #3803 review) — three behaviours a person meets with an
// invoice open beside the list, through the app:
// - the window resized across the large class and back while an invoice is
//   open: the invoice stays open, at its address, and one Back returns to
//   the list (no second entry, no second page);
// - Close (Escape) goes to the list's address and the list keeps its filter
//   and its search;
// - a direct link to an invoice the list does not show (filtered out) opens
//   it, and a link to one the reader cannot read says so in words, never an
//   empty pane.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Finder _k(String key) => find.byKey(ValueKey(key));

Future<(GoRouter, String)> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
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
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
  router.go('/invoices');
  await tester.pumpAndSettle();
  // The Invoices view: one line per invoice.
  await tester.tap(
    find.descendant(
      of: _k('invoicing-view'),
      matching: find.text('Invoices'),
    ),
  );
  await tester.pumpAndSettle();
  return (router, id);
}

String _at(GoRouter r) => r.routeInformationProvider.value.uri.path;

void _resize(WidgetTester tester, Size size) =>
    tester.view.physicalSize = size;

void main() {
  testWidgets('an invoice open at 1440 stays open across a resize to 1024 and '
      'back, at its address, and one Back returns to the list', (
    tester,
  ) async {
    final (router, id) = await _pump(tester, const Size(1440, 900));
    await tester.tap(_k('invoicing-row-$id'));
    await tester.pumpAndSettle();
    expect(_k('invoicing-panel-$id'), findsOneWidget);

    _resize(tester, const Size(1024, 768));
    await tester.pumpAndSettle();
    expect(_at(router), '/invoices/$id');
    expect(find.byType(InvoicePage), findsOneWidget, reason: 'one page');

    _resize(tester, const Size(1440, 900));
    await tester.pumpAndSettle();
    expect(_at(router), '/invoices/$id');
    expect(_k('invoicing-panel-$id'), findsOneWidget);
    expect(find.byType(InvoicePage), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(_at(router), '/invoices');
    expect(find.byType(InvoicePage), findsNothing);
    expect(_k('invoicing-row-$id'), findsOneWidget);
  });

  testWidgets('Escape goes to the list\'s address and the list keeps its '
      'filter and its search', (tester) async {
    final (router, id) = await _pump(tester, const Size(1440, 900));
    await tester.tap(_k('invoicing-search'));
    await tester.pumpAndSettle();
    await tester.enterText(_k('invoicing-search-field'), 'INV');
    await tester.pumpAndSettle();
    await tester.tap(_k('invoicing-row-$id'));
    await tester.pumpAndSettle();
    expect(_at(router), '/invoices/$id');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_at(router), '/invoices');
    expect(_k('invoicing-panel-$id'), findsNothing);
    expect(
      tester.widget<TextField>(_k('invoicing-search-field')).controller?.text,
      'INV',
      reason: 'the search survives Close',
    );
    expect(_k('invoicing-row-$id'), findsOneWidget);
  });

  testWidgets('a direct link to an invoice the list does not show opens it '
      'beside the list; one the reader cannot read is said in words', (
    tester,
  ) async {
    final (router, id) = await _pump(tester, const Size(1440, 900));
    // The Paid filter: the open invoice is not in the list.
    await tester.tap(_k('invoicing-filter-paid'));
    await tester.pumpAndSettle();
    expect(_k('invoicing-row-$id'), findsNothing);
    router.go('/invoices/$id');
    await tester.pumpAndSettle();
    expect(_k('invoicing-panel-$id'), findsOneWidget);
    expect(_k('invoice-page-unreadable'), findsNothing);

    router.go('/invoices/not-this-business');
    await tester.pumpAndSettle();
    expect(_k('invoicing-panel-not-this-business'), findsOneWidget);
    expect(_k('invoice-page-unreadable'), findsOneWidget);
  });
}
