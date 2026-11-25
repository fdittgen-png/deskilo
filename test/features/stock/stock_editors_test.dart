// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1) -- the editors of the stock configuration as a person uses them:
// the item's package units and codes, and the places. A person who may only
// look sees no editor; a mistake is shown under its field before anything is
// sent; a save sends the complete lists at the revision it read; a stale
// revision and a refusal are said, in the sheet, and nothing is shown saved.
// #4480 -- the item's editors are reached from its page, one worded action per section; the row opens the item.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/presentation/stock_items_screen.dart';
import 'package:deskilo/features/stock/presentation/stock_places_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/screens/stock_items_app.dart';
import 'stock_items_fakes.dart';

final _en = AppLocalizationsEn();

Future<void> _open(
  WidgetTester tester,
  FakeItemConfig config,
  Size size, {
  required Set<WorkspacePermission> held,
  bool lots = false,
  String? separator,
  FakeItemRegistry? registry,
  FakeMoneyRepository? money,
  Widget screen = const StockItemsScreen(),
}) async {
  await pumpApp(
    tester,
    null,
    router: stockItemsRouter(list: screen),
    size: size,
    overrides: [
      ...standardTestOverrides(money: money),
      stockQueriesProvider.overrideWithValue(FakeItemQueries()),
      stockConfigCommandsProvider.overrideWithValue(config),
      stockRegistryProvider.overrideWithValue(registry ?? FakeItemRegistry()),
      stockCodeResolverProvider.overrideWithValue(FakeItemResolver()),
      myPermissionsProvider.overrideWithValue(held),
      if (separator != null) stockAddressSeparatorProvider.overrideWithValue(separator),
      if (lots) enabledFeaturesSyncProvider.overrideWithValue({WorkspaceFeature.stockManagement, WorkspaceFeature.stockLots}),
    ],
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) => settleStock(tester);

/// The item [rowKey] opened from its row, then its action [action] tapped.
Future<void> _act(WidgetTester tester, String rowKey, String action) async {
  await openStockItem(tester, rowKey);
  await tapItemAction(tester, action);
}

const _manage = {WorkspacePermission.viewStock, WorkspacePermission.manageStock};

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('the price is changed from the item page, and the page shows it (#4470, #4480)', (tester) async {
        final money = FakeMoneyRepository()
          ..services.addAll(const [
            ServiceItem(id: 'i-Wine', workspaceId: 'ws-1', name: 'Wine', priceCents: 1250, active: true),
            ServiceItem(id: 'i-Tea', workspaceId: 'ws-1', name: 'Tea', priceCents: 300, active: true),
          ]);
        await _open(
          tester,
          FakeItemConfig(),
          size,
          held: {..._manage, WorkspacePermission.manageServices},
          money: money,
          registry: FakeItemRegistry(money: money),
        );
        await openStockItem(tester, 'i-Tea');
        final edit = find.byKey(const ValueKey('stock-item-edit-i-Tea'));
        expect(edit, findsOneWidget);
        expect(tester.getSize(edit).shortestSide, greaterThanOrEqualTo(48));
        expect(find.text(_en.stockItemEditDetails), findsOneWidget, reason: 'the edit says what it edits');
        await tapItemAction(tester, 'stock-item-edit-i-Tea');
        await tester.enterText(find.byKey(const ValueKey('services-price')), '15');
        await tester.ensureVisible(find.byKey(const ValueKey('services-save')));
        await tester.tap(find.byKey(const ValueKey('services-save')));
        await _settle(tester);
        expect(money.services.singleWhere((s) => s.id == 'i-Tea').priceCents, 1500);
        final overview = find.byKey(const ValueKey('stock-item-section-overview'));
        expect(find.descendant(of: overview, matching: find.text('€15.00')), findsOneWidget, reason: 'back on the item, the new price');
      });

      testWidgets('a member who manages the stock but not the services has no Edit for the price (#4470)', (tester) async {
        final money = FakeMoneyRepository()
          ..services.add(const ServiceItem(id: 'i-Tea', workspaceId: 'ws-1', name: 'Tea', priceCents: 300, active: true));
        await _open(tester, FakeItemConfig(), size, held: _manage, money: money, registry: FakeItemRegistry(money: money));
        await openStockItem(tester, 'i-Tea');
        expect(find.byKey(const ValueKey('stock-item-edit-i-Tea')), findsNothing);
        expect(find.byKey(const ValueKey('stock-edit-item-i-Tea')), findsOneWidget, reason: 'the stock settings stay');
      });

      testWidgets('a row shows price, what is on hand and the home address; the item shows barcode and cost', (tester) async {
        await _open(tester, FakeItemConfig(), size, held: _manage);
        final wine = tester.widget<ListTile>(find.byKey(const ValueKey('stock-item-i-Wine')));
        final text = (wine.subtitle! as Text).data!;
        for (final part in ['€12.50', 'MAIN-SALES-A03-B02-S4', _en.stockQuantityWithUnit('12', 'l')]) {
          expect(text.contains(part), true, reason: part);
        }
        expect(wine.trailing, isNot(isA<Wrap>()), reason: 'no action buttons crowd the row');
        final tea = tester.widget<ListTile>(find.byKey(const ValueKey('stock-item-i-Tea')));
        expect((tea.subtitle! as Text).data!.contains(_en.stockRegistryNoHome), true, reason: 'an item with no home place says so');
        expect(find.byKey(const ValueKey('stock-item-badge-i-Tea')), findsOneWidget, reason: 'and carries the badge');
        expect(find.byKey(const ValueKey('stock-item-badge-i-Wine')), findsNothing);
        await openStockItem(tester, 'i-Wine');
        final overview = find.byKey(const ValueKey('stock-item-section-overview'));
        expect(find.descendant(of: overview, matching: find.text('3017620422003')), findsOneWidget);
        expect(find.descendant(of: overview, matching: find.text('€7.00')), findsOneWidget, reason: 'a known cost is shown');
      });

      testWidgets('a reader who may not see finances sees "cost not shown", never a figure or a zero', (tester) async {
        await _open(tester, FakeItemConfig(), size, held: {WorkspacePermission.viewStock}, registry: FakeItemRegistry(costVisible: false));
        await openStockItem(tester, 'i-Wine');
        expect(find.descendant(of: find.byKey(const ValueKey('stock-item-section-overview')), matching: find.text(_en.stockRegistryCostHidden)), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-home-i-Wine')), findsNothing, reason: 'and may not set a home place');
      });

      testWidgets('"no home place" keeps what has none, and the filter is sent to the server', (tester) async {
        final registry = FakeItemRegistry();
        await _open(tester, FakeItemConfig(), size, held: _manage, registry: registry);
        await tester.tap(find.byKey(const ValueKey('stock-registry-no-home')));
        await _settle(tester);
        expect(registry.filters.last, (place: null, noHome: true));
        expect(find.byKey(const ValueKey('stock-item-i-Tea')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-item-i-Wine')), findsNothing);
      });

      testWidgets('the registry is read a page at a time, and a page that failed is asked again (#4401)', (tester) async {
        final registry = FakeItemRegistry(paged: true);
        await _open(tester, FakeItemConfig(), size, held: _manage, registry: registry);
        expect(find.byKey(const ValueKey('stock-item-i-Wine')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-item-i-Tea')), findsNothing, reason: 'the second page is not read yet');
        registry.failNext = true;
        await tester.tap(find.byKey(const ValueKey('stock-registry-more')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-items-failed')), findsOneWidget, reason: 'a failed page is said, never an empty list');
        await tester.tap(find.byKey(const ValueKey('stock-items-retry')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-item-i-Wine')), findsOneWidget, reason: 'the rows read stay');
        expect(find.byKey(const ValueKey('stock-item-i-Tea')), findsOneWidget, reason: 'the page that failed was asked again');
        expect(registry.pages, 3, reason: 'the first page is not read twice');
        expect(find.byKey(const ValueKey('stock-registry-more')), findsNothing, reason: 'nothing follows the last page');
      });

      testWidgets('a barcode typed into the search opens its item', (tester) async {
        await _open(tester, FakeItemConfig(), size, held: _manage);
        await tester.enterText(find.byKey(const ValueKey('stock-registry-search')), '4006381333931');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-item-page-i-Tea')), findsOneWidget, reason: 'the item Tea opened');
      });

      testWidgets('Enter on a search that still shows rows is a search, not an unknown code', (tester) async {
        await _open(tester, FakeItemConfig(), size, held: _manage);
        await tester.enterText(find.byKey(const ValueKey('stock-registry-search')), 'Tea');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-item-i-Tea')), findsOneWidget);
        expect(find.textContaining('Tea'), findsWidgets);
        expect(find.byType(SnackBar), findsNothing, reason: 'no "unknown code" over a list that is filled');
      });

      testWidgets('a search without its accents finds the accented name, and only it (#4428)', (tester) async {
        await _open(tester, FakeItemConfig(), size, held: _manage, registry: FakeItemRegistry(withCreme: true));
        await tester.enterText(find.byKey(const ValueKey('stock-registry-search')), 'CREME');
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-item-i-Creme')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-item-i-Tea')), findsNothing);
        expect(find.byKey(const ValueKey('stock-item-i-Wine')), findsNothing);
      });

      testWidgets('a home place is chosen from the places and sent with its request', (tester) async {
        final registry = FakeItemRegistry();
        await _open(tester, FakeItemConfig(), size, held: _manage, registry: registry);
        await _act(tester, 'i-Tea', 'stock-home-i-Tea');
        await tester.tap(find.byKey(const ValueKey('stock-home-place')));
        await _settle(tester);
        await tester.tap(find.text('MAIN-SALES-A03-B02-S4').last);
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-home-save')));
        await _settle(tester);
        expect(registry.homes.single, (item: 'i-Tea', variant: null, place: 'p-S4'));
        expect(registry.pages, 2, reason: 'the registry is read again after a save');
        expect(find.textContaining('MAIN-SALES-A03-B02-S4'), findsWidgets, reason: 'back on the item, the new home place');
      });

      testWidgets('a refused home place says why and keeps the sheet', (tester) async {
        final registry = FakeItemRegistry()..failWith = const StockConfigRefused('home_location_id', StockRefusal.homeInvalid);
        await _open(tester, FakeItemConfig(), size, held: _manage, registry: registry);
        await _act(tester, 'i-Tea', 'stock-home-i-Tea');
        await tester.tap(find.byKey(const ValueKey('stock-home-save')));
        await _settle(tester);
        expect(find.text(_en.stockReasonHomeInvalid), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-home-save')), findsOneWidget);
      });

      testWidgets('a person who may only look sees no editor', (tester) async {
        await _open(tester, FakeItemConfig(), size, held: {WorkspacePermission.viewStock});
        await openStockItem(tester, 'i-Wine');
        expect(find.byKey(const ValueKey('stock-edit-item-i-Wine')), findsNothing);
      });

      testWidgets('a mistake is shown under its field and nothing is sent; the fixed save sends the complete lists at the revision read', (tester) async {
        final config = FakeItemConfig();
        await _open(tester, config, size, held: _manage);
        await _act(tester, 'i-Wine', 'stock-edit-item-i-Wine');
        await tester.enterText(find.byKey(const ValueKey('stock-unit-0-den')), '0');
        await tester.tap(find.byKey(const ValueKey('stock-item-save')));
        await _settle(tester);
        expect(find.text(_en.stockReasonFactorInvalid), findsOneWidget);
        expect(config.savedItems, isEmpty, reason: 'a mistake the screen can see is not sent');
        await tester.enterText(find.byKey(const ValueKey('stock-unit-0-den')), '3');
        await tester.tap(find.byKey(const ValueKey('stock-item-save')));
        await _settle(tester);
        final (saved, _) = config.savedItems.single;
        expect(saved.revision, 4, reason: 'the revision that was read');
        expect(saved.units.single.factorDen, 3);
        expect(saved.codes.single.code, 'OWN-1', reason: 'the lists sent are the complete lists');
        expect(find.byKey(const ValueKey('stock-item-save')), findsNothing, reason: 'saved: the sheet closes');
      });

      testWidgets('a stale revision and a refusal are said in the sheet, which stays open', (tester) async {
        final config = FakeItemConfig()..failWith = const StockConfigStale();
        await _open(tester, config, size, held: _manage);
        await _act(tester, 'i-Wine', 'stock-edit-item-i-Wine');
        await tester.tap(find.byKey(const ValueKey('stock-item-save')));
        await _settle(tester);
        expect(find.text(_en.stockEditStale), findsOneWidget);
        config.failWith = const StockConfigRefused('codes[0].code', StockRefusal.codeDuplicate);
        await tester.tap(find.byKey(const ValueKey('stock-item-save')));
        await _settle(tester);
        expect(find.text(_en.stockReasonCodeDuplicate), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-item-save')), findsOneWidget, reason: 'nothing was saved: the sheet stays');
      });

      testWidgets('a package unit and a code are added to the lists the save sends', (tester) async {
        final config = FakeItemConfig();
        await _open(tester, config, size, held: _manage);
        await _act(tester, 'i-Wine', 'stock-edit-item-i-Wine');
        await tester.ensureVisible(find.byKey(const ValueKey('stock-item-add-unit')));
        await tester.tap(find.byKey(const ValueKey('stock-item-add-unit')));
        await _settle(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-unit-1-name')), 'case');
        await tester.enterText(find.byKey(const ValueKey('stock-unit-1-num')), '12');
        await tester.ensureVisible(find.byKey(const ValueKey('stock-item-save')));
        await tester.tap(find.byKey(const ValueKey('stock-item-save')));
        await _settle(tester);
        final (saved, _) = config.savedItems.single;
        expect(saved.units.map((u) => (u.unit, u.factorNum, u.factorDen)), [('third', 1, 3), ('case', 12, 1)]);
      });

      testWidgets('lots and expiry are offered only when asked for, and saved with the shelf life', (tester) async {
        final off = FakeItemConfig();
        await _open(tester, off, size, held: _manage);
        await _act(tester, 'i-Wine', 'stock-edit-item-i-Wine');
        expect(find.byKey(const ValueKey('stock-item-tracking')), findsNothing, reason: 'stockLots off: no tracking is offered');
      });

      testWidgets('with stockLots on the tracking and its shelf life are sent', (tester) async {
        final config = FakeItemConfig();
        await _open(tester, config, size, held: _manage, lots: true);
        await _act(tester, 'i-Wine', 'stock-edit-item-i-Wine');
        await tester.ensureVisible(find.byKey(const ValueKey('stock-item-tracking')));
        await tester.tap(find.text(_en.stockEditTrackingExpiry));
        await _settle(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-item-shelf-life')), '30');
        await tester.ensureVisible(find.byKey(const ValueKey('stock-item-save')));
        await tester.tap(find.byKey(const ValueKey('stock-item-save')));
        await _settle(tester);
        final (saved, _) = config.savedItems.single;
        expect((saved.tracking, saved.shelfLifeDays), ('expiry', 30));
      });

      testWidgets('the places are listed, the system ones not editable, and a new place is saved with its kind and code', (tester) async {
        final config = FakeItemConfig();
        await _open(tester, config, size, held: _manage, screen: const StockPlacesScreen());
        await _settle(tester);
        expect(find.text('MAIN'), findsOneWidget, reason: 'a root place is its code alone');
        expect(find.text(_en.stockPlaceVirtual), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stock-place-add')));
        await _settle(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-place-code')), 'SHELF-B');
        await tester.tap(find.byKey(const ValueKey('stock-place-save')));
        await _settle(tester);
        final saved = config.savedPlaces.single;
        expect((saved.place['code'], saved.place['kind'], saved.id), ('SHELF-B', 'site', null));
        expect(saved.place['receives_from_suppliers'], true, reason: 'a site says whether it receives from suppliers');
      });

      testWidgets('a place is listed by its composed address, and found by it', (tester) async {
        await _open(tester, FakeItemConfig(), size, held: _manage, screen: const StockPlacesScreen());
        await _settle(tester);
        expect(find.text('MAIN-SALES-A03-B02-S4'), findsOneWidget, reason: 'site, zone, aisle, bay and shelf, joined');
        await tester.enterText(find.byKey(const ValueKey('stock-places-search')), 'sales-a03-b02-s4');
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-place-p-S4')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-place-p-MAIN')), findsNothing, reason: 'the others are filtered out');
      });

      testWidgets('the separator is the business\'s own setting', (tester) async {
        await _open(tester, FakeItemConfig(), size, held: _manage, screen: const StockPlacesScreen(), separator: '.');
        await _settle(tester);
        expect(find.text('MAIN.SALES.A03.B02.S4'), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('stock-places-search')), 'MAIN.SALES.A03');
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-place-p-B02')), findsOneWidget, reason: 'found by the address as it is written');
      });

      testWidgets('a shelf is offered only the bays as its parent, a site no parent but the choice to receive', (tester) async {
        final config = FakeItemConfig();
        await _open(tester, config, size, held: _manage, screen: const StockPlacesScreen());
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-place-add')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-place-parent')), findsNothing, reason: 'a site is a root');
        expect(find.byKey(const ValueKey('stock-place-receives')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stock-place-kind')));
        await _settle(tester);
        await tester.tap(find.text(_en.stockPlaceKindShelf).last);
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-place-parent')));
        await _settle(tester);
        expect(find.text('B02').hitTestable(), findsWidgets, reason: 'the bay is offered');
        expect(find.text('SALES').hitTestable(), findsNothing, reason: 'a zone is not the level above a shelf');
        expect(find.byKey(const ValueKey('stock-place-role')), findsOneWidget, reason: 'a place below a site is picking or reserve');
      });

      testWidgets('a place refused for its code says why and keeps the sheet', (tester) async {
        final config = FakeItemConfig()..failWith = const StockConfigRefused('code', StockRefusal.codeDuplicate);
        await _open(tester, config, size, held: _manage, screen: const StockPlacesScreen());
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-place-p-MAIN')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-place-save')));
        await _settle(tester);
        expect(find.text(_en.stockReasonCodeDuplicate), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-place-save')), findsOneWidget);
      });
    });
  }
}
