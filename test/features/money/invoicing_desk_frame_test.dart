// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- the desk layout as the real app draws it. Every route sits
// in the app's frame (AppFrame), which narrows the screen and rewrites the
// window size; a screen pumped on its own never sees that. Here /invoices
// is reached through the app itself: the frame gives it the wide width, the
// customer table shows, and an invoice opens in the panel BESIDE the list,
// which keeps its table. #3607 — the invoice is in the address
// (/invoices/<id>): a large window keeps it beside the list (at 1440 with the
// sidebar, with the rail, and at 1920) and Back closes it; at 1024 it is a
// page of its own. #3773 — where the list's table and the narrowest pane do
// not fit side by side, the pane stands over the list's end.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/ui/kit/list_detail_scaffold.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_page.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_home_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      expect(router.routeInformationProvider.value.uri.path, '/invoices/$id');

      final panel = find.byKey(ValueKey('invoicing-panel-$id'));
      if (!beside) {
        expect(
          panel,
          findsNothing,
          reason: 'the list and the invoice do not fit',
        );
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
      // Back closes the panel; the list is where it was, on its Invoices view.
      router.pop();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/invoices');
      expect(panel, findsNothing);
      expect(find.byKey(ValueKey('invoicing-row-$id')), findsOneWidget);
    });
  }

  testWidgets('the pane stands beside the list from the list\'s minimum, the '
      'grip and the narrowest pane, and over the list one pixel before', (
    tester,
  ) async {
    Future<void> at(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 600,
              child: ListDetailScaffold(
                id: 'fit',
                paneStore: InMemoryPaneWidthStore(),
                listMin: kInvoicingListMinWidth,
                list: const SizedBox.expand(key: ValueKey('list')),
                selected: 'a',
                onClose: () {},
                detail: (_, _) => const SizedBox.expand(key: ValueKey('pane')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const both =
        kInvoicingListMinWidth +
        ListDetailMetrics.grip +
        ListDetailMetrics.paneMin;
    await at(both);
    expect(find.byKey(const ValueKey('list-detail-grip')), findsOneWidget);
    expect(
      tester.getTopRight(find.byKey(const ValueKey('list'))).dx,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const ValueKey('pane'))).dx,
      ),
    );
    await at(both - 1);
    expect(find.byKey(const ValueKey('list-detail-grip')), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('list'))).width, both - 1);
  });
}
