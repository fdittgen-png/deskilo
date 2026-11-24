// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1) -- the editors of the stock configuration as a person uses them:
// the item's package units and codes, and the places. A person who may only
// look sees no editor; a mistake is shown under its field before anything is
// sent; a save sends the complete lists at the revision it read; a stale
// revision and a refusal are said, in the sheet, and nothing is shown saved.
import 'package:deskilo/features/stock/domain/stock_code_resolver.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_config_commands.dart';
import 'package:deskilo/features/stock/domain/stock_drafts.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_queries.dart';
import 'package:deskilo/features/stock/domain/stock_registry.dart';
import 'package:deskilo/features/stock/domain/stock_variants.dart';
import 'package:deskilo/features/stock/presentation/stock_items_screen.dart';
import 'package:deskilo/features/stock/presentation/stock_places_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

class _Queries implements StockQueries {
  @override
  Future<StockPage<StockOnHandRow>> onHandPage(String workspaceId, {String? itemId, String? locationId, int limit = 50, StockCursor? after}) async =>
      const StockPage(rows: [], complete: true);

  @override
  Future<StockPage<StockMovementRow>> movementsPage(String workspaceId, {String? itemId, String? locationId, int limit = 50, StockCursor? after}) async =>
      const StockPage(rows: [], complete: true);

  @override
  Future<StockMovementRow?> movement(String workspaceId, String movementId) async => null;

  @override
  Future<List<StockPlace>> places(String workspaceId) async => const [StockPlace(id: 'p-MAIN', code: 'MAIN', name: 'Main')];

  @override
  Future<List<StockItem>> items(String workspaceId) async => const [StockItem(id: 'i-Wine', name: 'Wine', unit: 'l')];

  @override
  Future<List<StockItem>> unstocked(String workspaceId) async => const [];
}

/// The registry as the server answers it: Wine has its home shelf and a known cost, Tea has none.
class _Registry implements StockRegistry {
  _Registry({this.costVisible = true, this.withCreme = false, this.paged = false});

  /// One row a page (#4401: the registry is walked a page at a time).
  final bool paged;

  /// The next page read fails once.
  bool failNext = false;

  final bool costVisible;

  /// Also an item whose name carries an accent (#4428).
  final bool withCreme;
  final homes = <({String item, String? variant, String? place})>[];
  final filters = <({String? place, bool noHome})>[];
  StockConfigFailure? failWith;
  int pages = 0;

  List<StockRegistryRow> get _all => [
    StockRegistryRow(
      itemId: 'i-Wine', itemName: 'Wine', unit: 'l', barcode: '3017620422003', priceCents: 1250,
      cost: '700', costVisible: costVisible, homeLocationId: 'p-S4', homeCode: 'S4',
      homeAddressPath: 'MAIN\u001fSALES\u001fA03\u001fB02\u001fS4', onHand: ExactQuantity.parse('12'),
    ),
    StockRegistryRow(
      itemId: 'i-Tea', itemName: 'Tea', unit: 'piece', barcode: '4006381333931', priceCents: 300,
      costVisible: costVisible, onHand: ExactQuantity.parse('0'),
    ),
    if (withCreme)
      StockRegistryRow(itemId: 'i-Creme', itemName: 'Crème de marrons', unit: 'piece', costVisible: costVisible, onHand: ExactQuantity.parse('3')),
  ];

  @override
  Future<StockPage<StockRegistryRow>> page(String workspaceId, {String? placeId, bool noHome = false, int limit = 50, StockCursor? after}) async {
    filters.add((place: placeId, noHome: noHome));
    pages++;
    if (failNext) {
      failNext = false;
      throw StateError('the registry could not be read');
    }
    final rows = _all.where((r) => !noHome || r.homeLocationId == null).toList();
    if (!paged) return StockPage(rows: rows, complete: true);
    final from = (after?['n'] as int?) ?? 0;
    final complete = from + 1 >= rows.length;
    return StockPage(rows: rows.sublist(from, from + 1), complete: complete, next: complete ? null : {'n': from + 1});
  }

  @override
  Future<void> setHome(String workspaceId, {required String itemId, required String? variantId, required String? placeId, required String requestId}) async {
    if (failWith case final StockConfigFailure e) throw e;
    homes.add((item: itemId, variant: variantId, place: placeId));
  }
}

class _Config implements StockConfigCommands {
  StockConfigFailure? failWith;
  final savedItems = <(StockItemConfig, String)>[];
  final savedPlaces = <({Map<String, Object?> place, String? id, int? rev})>[];

  static const _wine = StockItemConfig(
    itemId: 'i-Wine', revision: 4, stockable: true, purchasable: true, sellable: true,
    inventoryUnit: 'l', tracking: 'none', shelfLifeDays: null,
    units: [StockUnitDraft(unit: 'third', factorNum: 1, factorDen: 3)],
    codes: [StockCodeDraft(code: 'OWN-1', kind: 'own')],
  );

  @override
  Future<StockItemConfig?> item(String workspaceId, String itemId) async => _wine;

  @override
  Future<List<StockPlaceConfig>> places(String workspaceId) async => const [
    StockPlaceConfig(id: 'p-MAIN', revision: 2, kind: 'warehouse', code: 'MAIN', name: 'Main', barcode: null, parentId: null, active: true, virtual: false),
    StockPlaceConfig(id: 'p-SALES', revision: 1, kind: 'zone', code: 'SALES', name: '', barcode: null, parentId: 'p-MAIN', active: true, virtual: false, pickRole: 'picking', addressPath: 'MAIN\u001fSALES'),
    StockPlaceConfig(id: 'p-A03', revision: 1, kind: 'aisle', code: 'A03', name: '', barcode: null, parentId: 'p-SALES', active: true, virtual: false, addressPath: 'MAIN\u001fSALES\u001fA03'),
    StockPlaceConfig(id: 'p-B02', revision: 1, kind: 'bay', code: 'B02', name: '', barcode: null, parentId: 'p-A03', active: true, virtual: false, addressPath: 'MAIN\u001fSALES\u001fA03\u001fB02'),
    StockPlaceConfig(id: 'p-S4', revision: 1, kind: 'shelf', code: 'S4', name: '', barcode: null, parentId: 'p-B02', active: true, virtual: false, pickRole: 'reserve', addressPath: 'MAIN\u001fSALES\u001fA03\u001fB02\u001fS4'),
    StockPlaceConfig(id: 'p-SUP', revision: 1, kind: 'supplier', code: 'SUPPLIER', name: '', barcode: null, parentId: null, active: true, virtual: true),
  ];

  @override
  Future<StockSaved> saveItem(String workspaceId, StockItemConfig config, String requestId) async {
    if (failWith case final StockConfigFailure e) throw e;
    savedItems.add((config, requestId));
    return (id: config.itemId, revision: config.revision + 1, replayed: false);
  }

  @override
  Future<StockSaved> savePlace(String workspaceId, {required StockPlaceDraft place, required String requestId, String? placeId, int? expectedRevision}) async {
    if (failWith case final StockConfigFailure e) throw e;
    savedPlaces.add((place: place.toJson(), id: placeId, rev: expectedRevision));
    return (id: placeId ?? 'p-new', revision: (expectedRevision ?? 0) + 1, replayed: false);
  }

  @override
  Future<List<StockDimension>> dimensions(String workspaceId) async => const [];
  @override
  Future<List<StockVariant>> variants(String workspaceId, String itemId) async => const [];
  @override
  Future<List<StockSupplierRef>> suppliers(String workspaceId) async => const [];
  @override
  Future<List<SupplierItemMapping>> mappings(String workspaceId) async => const [];
  @override
  Future<StockSaved> saveDimension(String workspaceId, {required StockDimension dimension, required String requestId, String? dimensionId, int? expectedRevision}) => throw UnimplementedError();
  @override
  Future<StockSaved> saveVariants(String workspaceId, String itemId, {required List<StockVariant> variants, required int expectedRevision, required String requestId}) => throw UnimplementedError();
  @override
  Future<StockSaved> saveMapping(String workspaceId, {required SupplierMappingDraft mapping, required String requestId, String? mappingId, int? expectedRevision}) => throw UnimplementedError();
}

/// Resolves the Tea's barcode the way the server does.
class _Resolver implements StockCodeResolver {
  @override
  Future<StockCodeResolution> resolve(String workspaceId, String code) async => code == '4006381333931'
      ? StockCodeResolution(kind: ScannedKind.item, code: code, item: const ScannedItem(id: 'i-Tea', name: 'Tea', unit: 'piece'))
      : StockCodeResolution.unknown(code);
}

Future<void> _open(
  WidgetTester tester,
  _Config config,
  Size size, {
  required Set<WorkspacePermission> held,
  bool lots = false,
  String? separator,
  _Registry? registry,
  Widget screen = const StockItemsScreen(),
}) async {
  await pumpApp(
    tester,
    screen,
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(_Queries()),
      stockConfigCommandsProvider.overrideWithValue(config),
      stockRegistryProvider.overrideWithValue(registry ?? _Registry()),
      stockCodeResolverProvider.overrideWithValue(_Resolver()),
      myPermissionsProvider.overrideWithValue(held),
      if (separator != null) stockAddressSeparatorProvider.overrideWithValue(separator),
      if (lots) enabledFeaturesSyncProvider.overrideWithValue({WorkspaceFeature.stockManagement, WorkspaceFeature.stockLots}),
    ],
  );
  await _settle(tester);
}

/// Two frames and a transition: what a sheet or a menu needs to arrive.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _manage = {WorkspacePermission.viewStock, WorkspacePermission.manageStock};

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('the registry shows barcode, unit, price, cost, home address and what is on hand', (tester) async {
        await _open(tester, _Config(), size, held: _manage);
        final wine = tester.widget<ListTile>(find.byKey(const ValueKey('stock-item-i-Wine')));
        final text = (wine.subtitle! as Text).data!;
        for (final part in ['3017620422003', 'l', 'MAIN-SALES-A03-B02-S4', _en.stockQuantityWithUnit('12', 'l'), _en.stockRegistryCostUnknown]) {
          if (part == _en.stockRegistryCostUnknown) {
            expect(text.contains(part), false, reason: 'a known cost is shown, not "unknown"');
          } else {
            expect(text.contains(part), true, reason: part);
          }
        }
        final tea = tester.widget<ListTile>(find.byKey(const ValueKey('stock-item-i-Tea')));
        expect((tea.subtitle! as Text).data!.contains(_en.stockRegistryNoHome), true, reason: 'an item with no home place says so');
      });

      testWidgets('a reader who may not see finances sees "cost not shown", never a figure or a zero', (tester) async {
        await _open(tester, _Config(), size, held: {WorkspacePermission.viewStock}, registry: _Registry(costVisible: false));
        final wine = tester.widget<ListTile>(find.byKey(const ValueKey('stock-item-i-Wine')));
        expect((wine.subtitle! as Text).data!.contains(_en.stockRegistryCostHidden), true);
        expect(find.byKey(const ValueKey('stock-home-i-Wine')), findsNothing, reason: 'and may not set a home place');
      });

      testWidgets('"no home place" keeps what has none, and the filter is sent to the server', (tester) async {
        final registry = _Registry();
        await _open(tester, _Config(), size, held: _manage, registry: registry);
        await tester.tap(find.byKey(const ValueKey('stock-registry-no-home')));
        await _settle(tester);
        expect(registry.filters.last, (place: null, noHome: true));
        expect(find.byKey(const ValueKey('stock-item-i-Tea')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-item-i-Wine')), findsNothing);
      });

      testWidgets('the registry is read a page at a time, and a page that failed is asked again (#4401)', (tester) async {
        final registry = _Registry(paged: true);
        await _open(tester, _Config(), size, held: _manage, registry: registry);
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
        await _open(tester, _Config(), size, held: _manage);
        await tester.enterText(find.byKey(const ValueKey('stock-registry-search')), '4006381333931');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-item-save')), findsOneWidget, reason: 'the item editor of Tea opened');
      });

      testWidgets('Enter on a search that still shows rows is a search, not an unknown code', (tester) async {
        await _open(tester, _Config(), size, held: _manage);
        await tester.enterText(find.byKey(const ValueKey('stock-registry-search')), 'Tea');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-item-i-Tea')), findsOneWidget);
        expect(find.textContaining('Tea'), findsWidgets);
        expect(find.byType(SnackBar), findsNothing, reason: 'no "unknown code" over a list that is filled');
      });

      testWidgets('a search without its accents finds the accented name, and only it (#4428)', (tester) async {
        await _open(tester, _Config(), size, held: _manage, registry: _Registry(withCreme: true));
        await tester.enterText(find.byKey(const ValueKey('stock-registry-search')), 'CREME');
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-item-i-Creme')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-item-i-Tea')), findsNothing);
        expect(find.byKey(const ValueKey('stock-item-i-Wine')), findsNothing);
      });

      testWidgets('a home place is chosen from the places and sent with its request', (tester) async {
        final registry = _Registry();
        await _open(tester, _Config(), size, held: _manage, registry: registry);
        await tester.tap(find.byKey(const ValueKey('stock-home-i-Tea')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-home-place')));
        await _settle(tester);
        await tester.tap(find.text('MAIN-SALES-A03-B02-S4').last);
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-home-save')));
        await _settle(tester);
        expect(registry.homes.single, (item: 'i-Tea', variant: null, place: 'p-S4'));
        expect(registry.pages, 2, reason: 'the registry is read again after a save');
      });

      testWidgets('a refused home place says why and keeps the sheet', (tester) async {
        final registry = _Registry()..failWith = const StockConfigRefused('home_location_id', 'home_invalid');
        await _open(tester, _Config(), size, held: _manage, registry: registry);
        await tester.tap(find.byKey(const ValueKey('stock-home-i-Tea')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-home-save')));
        await _settle(tester);
        expect(find.text(_en.stockReasonHomeInvalid), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-home-save')), findsOneWidget);
      });

      testWidgets('a person who may only look sees no editor', (tester) async {
        await _open(tester, _Config(), size, held: {WorkspacePermission.viewStock});
        expect(find.byKey(const ValueKey('stock-edit-item-i-Wine')), findsNothing);
      });

      testWidgets('a mistake is shown under its field and nothing is sent; the fixed save sends the complete lists at the revision read', (tester) async {
        final config = _Config();
        await _open(tester, config, size, held: _manage);
        await tester.tap(find.byKey(const ValueKey('stock-edit-item-i-Wine')));
        await _settle(tester);
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
        final config = _Config()..failWith = const StockConfigStale();
        await _open(tester, config, size, held: _manage);
        await tester.tap(find.byKey(const ValueKey('stock-edit-item-i-Wine')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-item-save')));
        await _settle(tester);
        expect(find.text(_en.stockEditStale), findsOneWidget);
        config.failWith = const StockConfigRefused('codes[0].code', 'code_duplicate');
        await tester.tap(find.byKey(const ValueKey('stock-item-save')));
        await _settle(tester);
        expect(find.text(_en.stockReasonCodeDuplicate), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-item-save')), findsOneWidget, reason: 'nothing was saved: the sheet stays');
      });

      testWidgets('a package unit and a code are added to the lists the save sends', (tester) async {
        final config = _Config();
        await _open(tester, config, size, held: _manage);
        await tester.tap(find.byKey(const ValueKey('stock-edit-item-i-Wine')));
        await _settle(tester);
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
        final off = _Config();
        await _open(tester, off, size, held: _manage);
        await tester.tap(find.byKey(const ValueKey('stock-edit-item-i-Wine')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-item-tracking')), findsNothing, reason: 'stockLots off: no tracking is offered');
      });

      testWidgets('with stockLots on the tracking and its shelf life are sent', (tester) async {
        final config = _Config();
        await _open(tester, config, size, held: _manage, lots: true);
        await tester.tap(find.byKey(const ValueKey('stock-edit-item-i-Wine')));
        await _settle(tester);
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
        final config = _Config();
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
        await _open(tester, _Config(), size, held: _manage, screen: const StockPlacesScreen());
        await _settle(tester);
        expect(find.text('MAIN-SALES-A03-B02-S4'), findsOneWidget, reason: 'site, zone, aisle, bay and shelf, joined');
        await tester.enterText(find.byKey(const ValueKey('stock-places-search')), 'sales-a03-b02-s4');
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-place-p-S4')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-place-p-MAIN')), findsNothing, reason: 'the others are filtered out');
      });

      testWidgets('the separator is the business\'s own setting', (tester) async {
        await _open(tester, _Config(), size, held: _manage, screen: const StockPlacesScreen(), separator: '.');
        await _settle(tester);
        expect(find.text('MAIN.SALES.A03.B02.S4'), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('stock-places-search')), 'MAIN.SALES.A03');
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-place-p-B02')), findsOneWidget, reason: 'found by the address as it is written');
      });

      testWidgets('a shelf is offered only the bays as its parent, a site no parent but the choice to receive', (tester) async {
        final config = _Config();
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
        final config = _Config()..failWith = const StockConfigRefused('code', 'code_duplicate');
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
