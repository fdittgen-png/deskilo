// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4480 -- Stock › Items at the addresses the app gives them: the list at `/stock/items` and an item at
// `/stock/items/<id>` (beside the list on a wide window, a page of its own on a phone), with the page it links to
// (where an item is). The item tests pump [stockItemsRouter] and open an item with [openStockItem] before they use
// its sections.
import 'package:deskilo/features/stock/presentation/stock_item_page.dart';
import 'package:deskilo/features/stock/presentation/stock_items_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The app's item addresses, opening at [at]; [list] stands in for the items list.
GoRouter stockItemsRouter({
  String at = '/stock/items',
  Widget? list,
}) => GoRouter(
  initialLocation: at,
  routes: [
    GoRoute(
      path: '/stock/items',
      builder: (context, state) =>
          list ??
          StockItemsScreen(addFirst: state.uri.queryParameters['add'] == '1'),
      routes: [GoRoute(path: ':itemId', pageBuilder: stockItemRoutePage)],
    ),
    GoRoute(
      path: '/stock/where/:itemId',
      builder: (context, state) =>
          Scaffold(key: ValueKey('where-${state.pathParameters['itemId']}')),
    ),
  ],
);

/// Two frames and a transition: what a page, a sheet or a menu needs to arrive.
Future<void> settleStock(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Taps the row [rowKey] (`StockRegistryRow.key`) of the items list: the item opens.
Future<void> openStockItem(WidgetTester tester, String rowKey) async {
  final row = find.byKey(ValueKey('stock-item-$rowKey'));
  await tester.scrollUntilVisible(
    row,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('stock-items-list')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(row);
  await settleStock(tester);
}

/// Brings the action [key] of the open item's page into view and taps it.
Future<void> tapItemAction(WidgetTester tester, String key) async {
  final action = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    action,
    200,
    scrollable: find
        .descendant(
          of: find.byType(StockItemPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
  await tester.tap(action);
  await settleStock(tester);
}
