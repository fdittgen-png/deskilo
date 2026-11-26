// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169, #4293, #4480 -- the stock as the item tests read it: Wine has its home shelf and a known cost, Tea has none;
// the item configuration of Wine; the places of the business; and a resolver that knows Tea's barcode.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/stock/domain/stock_code_resolver.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_config_commands.dart';
import 'package:deskilo/features/stock/domain/stock_drafts.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_queries.dart';
import 'package:deskilo/features/stock/domain/stock_registry.dart';
import 'package:deskilo/features/stock/domain/stock_variants.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// The stock's reads: Wine lies on its shelf, nothing else is on hand.
class FakeItemQueries implements StockQueries {
  @override
  Future<StockPage<StockOnHandRow>> onHandPage(
    String workspaceId, {
    String? itemId,
    String? locationId,
    int limit = 50,
    StockCursor? after,
  }) async => StockPage(
    rows: [
      if (itemId == 'i-Wine')
        StockOnHandRow(
          workspaceId: workspaceId,
          itemId: 'i-Wine',
          itemName: 'Wine',
          lotId: null,
          lotCode: null,
          locationId: 'p-S4',
          locationCode: 'S4',
          locationName: '',
          quantity: ExactQuantity.parse('12'),
          unit: 'l',
        ),
    ],
    complete: true,
  );

  @override
  Future<StockPage<StockMovementRow>> movementsPage(
    String workspaceId, {
    String? itemId,
    String? locationId,
    int limit = 50,
    StockCursor? after,
  }) async => const StockPage(rows: [], complete: true);

  @override
  Future<StockMovementRow?> movement(
    String workspaceId,
    String movementId,
  ) async => null;

  @override
  Future<List<StockPlace>> places(String workspaceId) async => const [
    StockPlace(id: 'p-MAIN', code: 'MAIN', name: 'Main'),
  ];

  @override
  Future<List<StockItem>> items(String workspaceId) async => const [
    StockItem(id: 'i-Wine', name: 'Wine', unit: 'l'),
  ];

  @override
  Future<List<StockItem>> unstocked(String workspaceId) async => const [];
}

/// The registry as the server answers it: Wine has its home shelf and a known cost, Tea has none.
class FakeItemRegistry implements StockRegistry {
  FakeItemRegistry({
    this.costVisible = true,
    this.withCreme = false,
    this.paged = false,
    this.money,
    this.extra = const [],
  });

  /// Further rows after Wine and Tea (an item with a long name, the variants of one).
  final List<StockRegistryRow> extra;

  /// The home places saved, by item: a save is read back (only the shelf S4 has an address here).
  final _saved = <String, String?>{};

  /// #4470: the services' price is the registry's price, as on the server.
  final FakeMoneyRepository? money;

  int? _price(String id, int fallback) =>
      money?.services.where((s) => s.id == id).firstOrNull?.priceCents ??
      fallback;

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
      itemId: 'i-Wine',
      itemName: 'Wine',
      unit: 'l',
      barcode: '3017620422003',
      priceCents: _price('i-Wine', 1250),
      cost: '700',
      costVisible: costVisible,
      homeLocationId: 'p-S4',
      homeCode: 'S4',
      homeAddressPath: 'MAIN\u001fSALES\u001fA03\u001fB02\u001fS4',
      onHand: ExactQuantity.parse('12'),
    ),
    StockRegistryRow(
      itemId: 'i-Tea',
      itemName: 'Tea',
      unit: 'piece',
      barcode: '4006381333931',
      priceCents: _price('i-Tea', 300),
      costVisible: costVisible,
      onHand: ExactQuantity.parse('0'),
      homeLocationId: _saved['i-Tea'],
      homeAddressPath: _saved['i-Tea'] == 'p-S4'
          ? 'MAIN\u001fSALES\u001fA03\u001fB02\u001fS4'
          : null,
    ),
    if (withCreme)
      StockRegistryRow(
        itemId: 'i-Creme',
        itemName: 'Crème de marrons',
        unit: 'piece',
        costVisible: costVisible,
        onHand: ExactQuantity.parse('3'),
      ),
    ...extra,
  ];

  @override
  Future<StockPage<StockRegistryRow>> page(
    String workspaceId, {
    String? placeId,
    bool noHome = false,
    int limit = 50,
    StockCursor? after,
  }) async {
    filters.add((place: placeId, noHome: noHome));
    pages++;
    if (failNext) {
      failNext = false;
      throw StateError('the registry could not be read');
    }
    final rows = _all
        .where((r) => !noHome || r.homeLocationId == null)
        .toList();
    if (!paged) return StockPage(rows: rows, complete: true);
    final from = (after?['n'] as int?) ?? 0;
    final complete = from + 1 >= rows.length;
    return StockPage(
      rows: rows.sublist(from, from + 1),
      complete: complete,
      next: complete ? null : {'n': from + 1},
    );
  }

  @override
  Future<void> setHome(
    String workspaceId, {
    required String itemId,
    required String? variantId,
    required String? placeId,
    required String requestId,
  }) async {
    if (failWith case final StockConfigFailure e) throw e;
    homes.add((item: itemId, variant: variantId, place: placeId));
    _saved[itemId] = placeId;
  }
}

class FakeItemConfig implements StockConfigCommands {
  FakeItemConfig({this.legacyUnit = false});

  /// Whether the item still holds a unit name typed before the units were picked from the master data (#4471).
  final bool legacyUnit;
  StockConfigFailure? failWith;
  final savedItems = <(StockItemConfig, String)>[];
  final savedPlaces = <({Map<String, Object?> place, String? id, int? rev})>[];

  static const wine = StockItemConfig(
    itemId: 'i-Wine',
    revision: 4,
    stockable: true,
    purchasable: true,
    sellable: true,
    inventoryUnit: 'l',
    tracking: 'none',
    shelfLifeDays: null,
    units: [StockUnitDraft(unit: 'kg', factorNum: 1, factorDen: 3)],
    codes: [StockCodeDraft(code: 'OWN-1', kind: 'own')],
  );

  static final _legacyWine = StockItemConfig(
    itemId: wine.itemId,
    revision: wine.revision,
    stockable: true,
    purchasable: true,
    sellable: true,
    inventoryUnit: 'l',
    tracking: 'none',
    shelfLifeDays: null,
    units: const [StockUnitDraft(unit: 'third', factorNum: 1, factorDen: 3)],
    codes: const [StockCodeDraft(code: 'OWN-1', kind: 'own')],
  );

  @override
  Future<StockItemConfig?> item(String workspaceId, String itemId) async =>
      legacyUnit ? _legacyWine : wine;

  @override
  Future<List<StockPlaceConfig>> places(String workspaceId) async => const [
    StockPlaceConfig(
      id: 'p-MAIN',
      revision: 2,
      kind: 'warehouse',
      code: 'MAIN',
      name: 'Main',
      barcode: null,
      parentId: null,
      active: true,
      virtual: false,
    ),
    StockPlaceConfig(
      id: 'p-SALES',
      revision: 1,
      kind: 'zone',
      code: 'SALES',
      name: '',
      barcode: null,
      parentId: 'p-MAIN',
      active: true,
      virtual: false,
      pickRole: 'picking',
      addressPath: 'MAIN\u001fSALES',
    ),
    StockPlaceConfig(
      id: 'p-A03',
      revision: 1,
      kind: 'aisle',
      code: 'A03',
      name: '',
      barcode: null,
      parentId: 'p-SALES',
      active: true,
      virtual: false,
      addressPath: 'MAIN\u001fSALES\u001fA03',
    ),
    StockPlaceConfig(
      id: 'p-B02',
      revision: 1,
      kind: 'bay',
      code: 'B02',
      name: '',
      barcode: null,
      parentId: 'p-A03',
      active: true,
      virtual: false,
      addressPath: 'MAIN\u001fSALES\u001fA03\u001fB02',
    ),
    StockPlaceConfig(
      id: 'p-S4',
      revision: 1,
      kind: 'shelf',
      code: 'S4',
      name: '',
      barcode: null,
      parentId: 'p-B02',
      active: true,
      virtual: false,
      pickRole: 'reserve',
      addressPath: 'MAIN\u001fSALES\u001fA03\u001fB02\u001fS4',
    ),
    StockPlaceConfig(
      id: 'p-SUP',
      revision: 1,
      kind: 'supplier',
      code: 'SUPPLIER',
      name: '',
      barcode: null,
      parentId: null,
      active: true,
      virtual: true,
    ),
  ];

  @override
  Future<StockSaved> saveItem(
    String workspaceId,
    StockItemConfig config,
    String requestId,
  ) async {
    if (failWith case final StockConfigFailure e) throw e;
    savedItems.add((config, requestId));
    return (id: config.itemId, revision: config.revision + 1, replayed: false);
  }

  @override
  Future<StockSaved> createItem(
    String workspaceId,
    NewStockItemDraft item,
    String requestId,
  ) => throw UnimplementedError('not used here');

  @override
  Future<StockSaved> savePlace(
    String workspaceId, {
    required StockPlaceDraft place,
    required String requestId,
    String? placeId,
    int? expectedRevision,
  }) async {
    if (failWith case final StockConfigFailure e) throw e;
    savedPlaces.add((
      place: place.toJson(),
      id: placeId,
      rev: expectedRevision,
    ));
    return (
      id: placeId ?? 'p-new',
      revision: (expectedRevision ?? 0) + 1,
      replayed: false,
    );
  }

  @override
  Future<List<StockDimension>> dimensions(String workspaceId) async => const [];
  @override
  Future<List<StockVariant>> variants(
    String workspaceId,
    String itemId,
  ) async => const [];
  @override
  Future<List<StockSupplierRef>> suppliers(String workspaceId) async =>
      const [];
  @override
  Future<List<SupplierItemMapping>> mappings(String workspaceId) async =>
      const [];
  @override
  Future<StockSaved> saveDimension(
    String workspaceId, {
    required StockDimension dimension,
    required String requestId,
    String? dimensionId,
    int? expectedRevision,
  }) => throw UnimplementedError();
  @override
  Future<StockSaved> saveVariants(
    String workspaceId,
    String itemId, {
    required List<StockVariant> variants,
    required int expectedRevision,
    required String requestId,
  }) => throw UnimplementedError();
  @override
  Future<StockSaved> saveMapping(
    String workspaceId, {
    required SupplierMappingDraft mapping,
    required String requestId,
    String? mappingId,
    int? expectedRevision,
  }) => throw UnimplementedError();
}

/// Resolves the Tea's barcode the way the server does.
class FakeItemResolver implements StockCodeResolver {
  @override
  Future<StockCodeResolution> resolve(String workspaceId, String code) async =>
      code == '4006381333931'
      ? StockCodeResolution(
          kind: ScannedKind.item,
          code: code,
          item: const ScannedItem(id: 'i-Tea', name: 'Tea', unit: 'piece'),
        )
      : StockCodeResolution.unknown(code);
}
