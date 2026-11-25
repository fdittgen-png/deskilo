// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350: what the Stock page says when nothing is in stock yet, at a phone and a desk width. A business that has
// just switched the goods ledger on has no place and no item: the page says where to start, with "Add your
// first place" and "Add your first item" for whoever manages the stock (and no button for whoever does not);
// with a place and an item it says only that nothing is in stock. "Add an item" chooses among the services
// that are not kept in stock yet; with none, it says to add a service first and offers to open the services.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_queries.dart';
import 'package:deskilo/features/stock/domain/stock_registry.dart';
import 'package:deskilo/features/stock/presentation/stock_items_screen.dart';
import 'package:deskilo/features/stock/presentation/stock_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/screens/stock_items_app.dart';

final _en = AppLocalizationsEn();

class _Stock implements StockQueries {
  _Stock({this.kept = const [], this.unstockedItems = const [], this.placesKnown = true});

  final List<StockItem> kept;
  final List<StockItem> unstockedItems;
  final bool placesKnown;

  @override
  Future<StockPage<StockOnHandRow>> onHandPage(String workspaceId, {String? itemId, String? locationId, int limit = 50, StockCursor? after}) async =>
      const StockPage(rows: [], complete: true);

  @override
  Future<List<StockItem>> items(String workspaceId) async => kept;

  @override
  Future<List<StockItem>> unstocked(String workspaceId) async => unstockedItems;

  @override
  Future<List<StockPlace>> places(String workspaceId) async => placesKnown ? const [StockPlace(id: 'p', code: 'MAIN', name: 'Main')] : const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Registry implements StockRegistry {
  @override
  Future<StockPage<StockRegistryRow>> page(String workspaceId, {String? placeId, bool noHome = false, int limit = 50, StockCursor? after}) async =>
      const StockPage(rows: [], complete: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(WidgetTester tester, Widget home, _Stock stock, Size size, {Set<WorkspacePermission>? held, bool noPlaces = false}) async {
  // #4480 -- the items list opens its items at their addresses: it is pumped under the app's item routes.
  final items = home is StockItemsScreen;
  await pumpApp(
    tester,
    items ? null : home,
    router: items ? stockItemsRouter(list: home) : null,
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(stock),
      stockRegistryProvider.overrideWithValue(_Registry()),
      if (noPlaces) stockPlaceConfigsProvider.overrideWith((ref, id) async => const <StockPlaceConfig>[]) else stockConfigCommandsProvider.overrideWithValue(DemoStockConfigCommands('ws-1')),
      myPermissionsProvider.overrideWithValue(held ?? {WorkspacePermission.viewStock, WorkspacePermission.manageStock}),
    ],
  );
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('a business with no place and no item is told where to start', (tester) async {
        await _open(tester, const StockScreen(), _Stock(placesKnown: false), size, noPlaces: true);
        expect(find.byKey(const ValueKey('stock-first-run')), findsOneWidget);
        expect(find.text(_en.stockFirstRunPlace), findsOneWidget);
        expect(find.text(_en.stockFirstRunItem), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-empty')), findsNothing);
      });

      testWidgets('someone who may not manage the stock is told, with no button that would be refused', (tester) async {
        await _open(tester, const StockScreen(), _Stock(placesKnown: false), size, noPlaces: true, held: {WorkspacePermission.viewStock});
        expect(find.byKey(const ValueKey('stock-first-run')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-first-place')), findsNothing);
        expect(find.byKey(const ValueKey('stock-first-item')), findsNothing);
      });

      testWidgets('with an item the page asks only for the first place', (tester) async {
        await _open(tester, const StockScreen(), _Stock(kept: const [StockItem(id: 'i', name: 'Beans', unit: 'kg')], placesKnown: false), size, noPlaces: true);
        expect(find.byKey(const ValueKey('stock-first-place')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-first-item')), findsNothing);
      });

      testWidgets('with a place and an item it says only that nothing is in stock', (tester) async {
        await _open(tester, const StockScreen(), _Stock(kept: const [StockItem(id: 'i', name: 'Beans', unit: 'kg')]), size);
        expect(find.byKey(const ValueKey('stock-first-run')), findsNothing);
        expect(find.text(_en.stockEmpty), findsOneWidget);
      });

      testWidgets('"Add an item" with no service to choose from says to add a service first', (tester) async {
        await _open(tester, const StockItemsScreen(), _Stock(), size);
        await tester.tap(find.byKey(const ValueKey('stock-item-add')));
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byKey(const ValueKey('stock-item-add-none')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-item-add-services')), findsOneWidget);
      });

      testWidgets('"Add an item" lists the services that are not kept in stock yet', (tester) async {
        await _open(tester, const StockItemsScreen(), _Stock(unstockedItems: const [StockItem(id: 's1', name: 'Latte', unit: 'piece')]), size);
        await tester.tap(find.byKey(const ValueKey('stock-item-add')));
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byKey(const ValueKey('stock-item-candidate-s1')), findsOneWidget);
        expect(find.text('Latte'), findsOneWidget);
      });
    });
  }
}
