// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3842 — the purchase orders at the addresses the app gives them: the list,
// the order's form (`new`, `<id>/edit`) and an order's record
// (`order/<id>`, beside the table on a large window). The order tests pump
// this and open an order with [openOrder] before they use what it offers.
import 'package:deskilo/core/navigation/list_detail_route.dart';
import 'package:deskilo/features/money/presentation/screens/purchase_order_page.dart';
import 'package:deskilo/features/money/presentation/screens/purchase_orders_screen.dart';
import 'package:deskilo/features/money/presentation/widgets/purchase_order_record.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The app's order addresses over [overrides], opening at the list.
/// [retryReads] false leaves a failed read failed: the failure is then the
/// state under test.
Widget purchaseOrdersApp(
  List<Override> overrides, {
  bool retryReads = true,
}) => ProviderScope(
  retry: retryReads ? null : (_, _) => null,
  overrides: overrides,
  child: MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      initialLocation: '/money/purchase-orders',
      routes: [
        GoRoute(
          path: '/money/purchase-orders',
          builder: (context, state) => const PurchaseOrdersScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const PurchaseOrderPage(),
            ),
            GoRoute(
              path: 'order/:id',
              pageBuilder: (context, state) => recordPage(
                context,
                state,
                (id) => PurchaseOrderRecord(orderId: id),
              ),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) =>
                  PurchaseOrderPage(orderId: state.pathParameters['id']),
            ),
          ],
        ),
      ],
    ),
  ),
);

/// Opens the order [reference] from the list — its row in the table, its
/// card on a phone: the order's record then holds the order's actions.
Future<void> openOrder(WidgetTester tester, String reference) async {
  final cell = find.descendant(
    of: find.byKey(const ValueKey('records-rows')),
    matching: find.text(reference),
  );
  final card = find.byKey(ValueKey('purchase-order-$reference'));
  final row = cell.evaluate().isEmpty ? card : cell;
  if (row.evaluate().isEmpty) return;
  await tester.tap(row.first);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// The address the app shows.
String orderAddress(WidgetTester tester) => GoRouter.of(
  tester.element(find.byType(PurchaseOrdersScreen, skipOffstage: false).first),
).state.uri.path;
