// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1) -- the editors of the stock configuration as a person uses them:
// the item's package units and codes, and the places. A person who may only
// look sees no editor; a mistake is shown under its field before anything is
// sent; a save sends the complete lists at the revision it read; a stale
// revision and a refusal are said, in the sheet, and nothing is shown saved.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_config_commands.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_queries.dart';
import 'package:deskilo/features/stock/domain/stock_variants.dart';
import 'package:deskilo/features/stock/presentation/stock_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
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
    StockPlaceConfig(id: 'p-SUP', revision: 1, kind: 'supplier', code: 'SUPPLIER', name: '', barcode: null, parentId: null, active: true, virtual: true),
  ];

  @override
  Future<StockSaved> saveItem(String workspaceId, StockItemConfig config, String requestId) async {
    if (failWith case final StockConfigFailure e) throw e;
    savedItems.add((config, requestId));
    return (id: config.itemId, revision: config.revision + 1, replayed: false);
  }

  @override
  Future<StockSaved> savePlace(String workspaceId, {required Map<String, Object?> place, required String requestId, String? placeId, int? expectedRevision}) async {
    if (failWith case final StockConfigFailure e) throw e;
    savedPlaces.add((place: place, id: placeId, rev: expectedRevision));
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
  Future<StockSaved> saveDimension(String workspaceId, {required Map<String, Object?> dimension, required String requestId, String? dimensionId, int? expectedRevision}) => throw UnimplementedError();
  @override
  Future<StockSaved> saveVariants(String workspaceId, String itemId, {required List<StockVariant> variants, required int expectedRevision, required String requestId}) => throw UnimplementedError();
  @override
  Future<StockSaved> saveMapping(String workspaceId, {required Map<String, Object?> mapping, required String requestId, String? mappingId, int? expectedRevision}) => throw UnimplementedError();
}

Future<void> _open(WidgetTester tester, _Config config, Size size, {required Set<WorkspacePermission> held, bool lots = false}) async {
  await pumpApp(
    tester,
    const StockScreen(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(_Queries()),
      stockConfigCommandsProvider.overrideWithValue(config),
      myPermissionsProvider.overrideWithValue(held),
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

Future<void> _chooseWine(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('stock-filter-item')));
  await _settle(tester);
  await tester.tap(find.text('Wine').last);
  await _settle(tester);
}

const _manage = {WorkspacePermission.viewStock, WorkspacePermission.manageStock};

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('a person who may only look sees no editor', (tester) async {
        await _open(tester, _Config(), size, held: {WorkspacePermission.viewStock});
        await _chooseWine(tester);
        expect(find.byKey(const ValueKey('stock-edit-item')), findsNothing);
        expect(find.byKey(const ValueKey('stock-places')), findsNothing);
      });

      testWidgets('a mistake is shown under its field and nothing is sent; the fixed save sends the complete lists at the revision read', (tester) async {
        final config = _Config();
        await _open(tester, config, size, held: _manage);
        await _chooseWine(tester);
        await tester.tap(find.byKey(const ValueKey('stock-edit-item')));
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
        await _chooseWine(tester);
        await tester.tap(find.byKey(const ValueKey('stock-edit-item')));
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
        await _chooseWine(tester);
        await tester.tap(find.byKey(const ValueKey('stock-edit-item')));
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
        await _chooseWine(tester);
        await tester.tap(find.byKey(const ValueKey('stock-edit-item')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-item-tracking')), findsNothing, reason: 'stockLots off: no tracking is offered');
      });

      testWidgets('with stockLots on the tracking and its shelf life are sent', (tester) async {
        final config = _Config();
        await _open(tester, config, size, held: _manage, lots: true);
        await _chooseWine(tester);
        await tester.tap(find.byKey(const ValueKey('stock-edit-item')));
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
        await _open(tester, config, size, held: _manage);
        await tester.tap(find.byKey(const ValueKey('stock-places')));
        await _settle(tester);
        expect(find.text('MAIN · Main'), findsOneWidget);
        expect(find.text(_en.stockPlaceVirtual), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stock-place-add')));
        await _settle(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-place-code')), 'SHELF-B');
        await tester.tap(find.byKey(const ValueKey('stock-place-save')));
        await _settle(tester);
        final saved = config.savedPlaces.single;
        expect((saved.place['code'], saved.place['kind'], saved.id), ('SHELF-B', 'warehouse', null));
      });

      testWidgets('a place refused for its code says why and keeps the sheet', (tester) async {
        final config = _Config()..failWith = const StockConfigRefused('code', 'code_duplicate');
        await _open(tester, config, size, held: _manage);
        await tester.tap(find.byKey(const ValueKey('stock-places')));
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
