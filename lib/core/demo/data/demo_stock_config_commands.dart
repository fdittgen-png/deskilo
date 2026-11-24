// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B1) -- the Demo's stock configuration, behind the same port as the
// server's: the reference business edits the units, codes and places of its
// small shop stock, in memory. A save names the revision it read, a stale one
// is refused, and a content that is not valid is refused with its field and
// reason as the server does (the same local check). Nothing leaves the
// process. Another Demo business keeps no stock, so it reads nothing.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_config_check.dart';
import 'package:deskilo/features/stock/domain/stock_config_commands.dart';
import 'package:deskilo/features/stock/domain/stock_drafts.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_variants.dart';

import 'demo_stock_candidates.dart';

/// The in-memory configuration of the reference business.
class DemoStockConfigCommands implements StockConfigCommands {
  DemoStockConfigCommands(this.workspaceId, {this.candidates});

  /// #4350 -- the services that may start being kept in stock, and the ones that have.
  final DemoStockCandidates? candidates;

  final String workspaceId;

  /// #4442 -- whether an item of the business has [code] as a packaging unit (a box of 6): a unit of measure cannot take it.
  bool packages(String businessId, String code) => _mine(businessId) && _items.values.any((i) => i.units.any((u) => u.unit == code));

  final Map<String, StockItemConfig> _items = {
    'demo-item-beans': const StockItemConfig(
      itemId: 'demo-item-beans', revision: 1, stockable: true, purchasable: true, sellable: true,
      inventoryUnit: 'kg', tracking: 'none', shelfLifeDays: null, units: [], codes: [],
    ),
    'demo-item-milk': const StockItemConfig(
      itemId: 'demo-item-milk', revision: 1, stockable: true, purchasable: true, sellable: true,
      inventoryUnit: 'l', tracking: 'none', shelfLifeDays: null, units: [], codes: [],
    ),
    'demo-item-mugs': const StockItemConfig(
      itemId: 'demo-item-mugs', revision: 1, stockable: true, purchasable: true, sellable: true,
      inventoryUnit: 'piece', tracking: 'none', shelfLifeDays: null,
      units: [
        StockUnitDraft(unit: 'box', factorNum: 6, factorDen: 1, defaultPurchase: true),
        StockUnitDraft(unit: 'carton', factorNum: 12, factorDen: 1),
      ],
      codes: [
        StockCodeDraft(code: 'MUG-001', kind: 'own'),
        StockCodeDraft(code: 'MUG-CARTON', kind: 'own', unit: 'carton'),
      ],
    ),
    'demo-item-shirt': const StockItemConfig(
      itemId: 'demo-item-shirt', revision: 1, stockable: true, purchasable: true, sellable: true,
      inventoryUnit: 'piece', tracking: 'none', shelfLifeDays: null, units: [], codes: [],
    ),
    'demo-item-basket': const StockItemConfig(
      itemId: 'demo-item-basket', revision: 1, stockable: true, purchasable: true, sellable: true,
      inventoryUnit: 'piece', tracking: 'serial', shelfLifeDays: null, units: [], codes: [],
    ),
    'demo-item-apples': const StockItemConfig(
      itemId: 'demo-item-apples', revision: 1, stockable: true, purchasable: true, sellable: true,
      inventoryUnit: 'piece', tracking: 'lot', shelfLifeDays: 21, units: [], codes: [],
    ),
    'demo-item-syrup': const StockItemConfig(
      itemId: 'demo-item-syrup', revision: 1, stockable: true, purchasable: true, sellable: true,
      inventoryUnit: 'l', tracking: 'none', shelfLifeDays: null,
      units: [StockUnitDraft(unit: 'third', factorNum: 1, factorDen: 3)], codes: [],
    ),
  };

  final Map<String, StockPlaceConfig> _places = {
    'demo-place-main': const StockPlaceConfig(
      id: 'demo-place-main', revision: 1, kind: 'warehouse', code: 'MAIN', name: 'Main store',
      barcode: null, parentId: null, active: true, virtual: false, addressPath: 'MAIN',
    ),
    'demo-place-shelf': const StockPlaceConfig(
      id: 'demo-place-shelf', revision: 1, kind: 'shelf', code: 'SHELF-A', name: 'Shelf A',
      barcode: null, parentId: 'demo-place-main', active: true, virtual: false,
      addressPath: 'MAIN${stockAddressJoint}SHELF-A',
    ),
    // #4293 -- two sites: the store (MAIN, as before) and a central depot, each with a sales
    // and a back-room zone, and one full five-level address MAIN-SALES-A03-B02-S4.
    'demo-place-depot': const StockPlaceConfig(
      id: 'demo-place-depot', revision: 1, kind: 'site', code: 'DEPOT', name: 'Central depot',
      barcode: null, parentId: null, active: true, virtual: false, addressPath: 'DEPOT',
    ),
    'demo-place-sales': const StockPlaceConfig(
      id: 'demo-place-sales', revision: 1, kind: 'zone', code: 'SALES', name: 'Sales floor',
      barcode: null, parentId: 'demo-place-main', active: true, virtual: false,
      pickRole: 'picking', addressPath: 'MAIN${stockAddressJoint}SALES',
    ),
    'demo-place-back': const StockPlaceConfig(
      id: 'demo-place-back', revision: 1, kind: 'zone', code: 'BACK', name: 'Back room',
      barcode: null, parentId: 'demo-place-main', active: true, virtual: false,
      pickRole: 'reserve', addressPath: 'MAIN${stockAddressJoint}BACK',
    ),
    'demo-place-depot-back': const StockPlaceConfig(
      id: 'demo-place-depot-back', revision: 1, kind: 'zone', code: 'BACK', name: 'Depot reserve',
      barcode: null, parentId: 'demo-place-depot', active: true, virtual: false,
      pickRole: 'reserve', addressPath: 'DEPOT${stockAddressJoint}BACK',
    ),
    'demo-place-aisle': const StockPlaceConfig(
      id: 'demo-place-aisle', revision: 1, kind: 'aisle', code: 'A03', name: '',
      barcode: null, parentId: 'demo-place-sales', active: true, virtual: false,
      addressPath: 'MAIN${stockAddressJoint}SALES${stockAddressJoint}A03',
    ),
    'demo-place-bay': const StockPlaceConfig(
      id: 'demo-place-bay', revision: 1, kind: 'bay', code: 'B02', name: '',
      barcode: null, parentId: 'demo-place-aisle', active: true, virtual: false,
      addressPath: 'MAIN${stockAddressJoint}SALES${stockAddressJoint}A03${stockAddressJoint}B02',
    ),
    'demo-place-eye-shelf': const StockPlaceConfig(
      id: 'demo-place-eye-shelf', revision: 1, kind: 'shelf', code: 'S4', name: 'Eye level',
      barcode: null, parentId: 'demo-place-bay', active: true, virtual: false, pickRole: 'picking',
      addressPath: 'MAIN${stockAddressJoint}SALES${stockAddressJoint}A03${stockAddressJoint}B02${stockAddressJoint}S4',
    ),
    // #4170 -- a second site, and the places the server keeps for the goods on their way and the goods written off.
    'demo-place-branch': const StockPlaceConfig(
      id: 'demo-place-branch', revision: 1, kind: 'warehouse', code: 'BRANCH', name: 'Branch shop',
      barcode: null, parentId: null, active: true, virtual: false,
    ),
    'demo-place-transit': const StockPlaceConfig(
      id: 'demo-place-transit', revision: 1, kind: 'in_transit', code: 'TRANSIT', name: '',
      barcode: null, parentId: null, active: true, virtual: true,
    ),
    'demo-place-loss': const StockPlaceConfig(
      id: 'demo-place-loss', revision: 1, kind: 'loss', code: 'LOSS', name: '',
      barcode: null, parentId: null, active: true, virtual: true,
    ),
    'demo-place-supplier': const StockPlaceConfig(
      id: 'demo-place-supplier', revision: 1, kind: 'supplier', code: 'SUPPLIER', name: '',
      barcode: null, parentId: null, active: true, virtual: true,
    ),
    // #4173 -- where a sale's goods go: the server's own customer place, which holds nothing.
    'demo-place-customer': const StockPlaceConfig(
      id: 'demo-place-customer', revision: 1, kind: 'customer', code: 'CUSTOMER', name: '',
      barcode: null, parentId: null, active: true, virtual: true,
    ),
  };

  /// The items the Demo's movements name: their unit and tracking are fixed.
  static const _withHistory = {'demo-item-beans', 'demo-item-milk', 'demo-item-mugs', 'demo-item-syrup'};

  int _next = 1;

  bool _mine(String id) => id == workspaceId;

  @override
  Future<StockItemConfig?> item(String workspaceId, String itemId) async {
    if (!_mine(workspaceId)) return null;
    if (_items[itemId] case final known?) return known;
    // a service that is not an item yet: its settings as they stand, the stock one off
    final candidate = (await candidates?.unstocked() ?? const []).where((c) => c.id == itemId).firstOrNull;
    return candidate == null
        ? null
        : StockItemConfig(
            itemId: itemId, revision: 1, stockable: false, purchasable: true, sellable: true,
            inventoryUnit: candidate.unit, tracking: 'none', shelfLifeDays: null, units: const [], codes: const [],
          );
  }

  @override
  Future<List<StockPlaceConfig>> places(String workspaceId) async =>
      _mine(workspaceId) ? _places.values.toList() : const [];

  /// #4403 -- the places and the packaging units, as the stock ledger reads them (in memory, no wait).
  Map<String, StockPlaceConfig> get placeMap => _places;
  List<StockUnitDraft> unitsOf(String itemId) => _items[itemId]?.units ?? const [];

  @override
  Future<StockSaved> saveItem(String workspaceId, StockItemConfig config, String requestId) async {
    final old = _mine(workspaceId) ? await item(workspaceId, config.itemId) : null;
    if (old == null) throw const StockConfigRefused('item_id', StockRefusal.itemForeign);
    if (old.revision != config.revision) throw const StockConfigStale();
    // The first movement fixed the tracking of the shop's goods.
    if (config.tracking != old.tracking && _withHistory.contains(config.itemId)) throw const StockConfigInUse();
    final problems = checkStockItem(units: config.units, codes: config.codes);
    if (problems.isNotEmpty) {
      final first = problems.entries.first;
      throw StockConfigRefused(first.key, first.value);
    }
    final revision = old.revision + 1;
    // the unit is fixed by the first movement; a service that has none yet takes the one chosen
    final turnsOn = config.stockable && !old.stockable;
    final unit = turnsOn ? config.inventoryUnit : old.inventoryUnit;
    _items[config.itemId] = StockItemConfig(
      itemId: config.itemId, revision: revision, stockable: config.stockable,
      purchasable: config.purchasable, sellable: config.sellable,
      inventoryUnit: unit, tracking: config.tracking, shelfLifeDays: config.shelfLifeDays,
      units: config.units, codes: config.codes,
    );
    // a service turned into an item joins the goods ledger the other pages read
    final turnedOn = candidates;
    if (turnedOn != null && turnsOn && !turnedOn.added.any((a) => a.id == config.itemId)) {
      final named = (await turnedOn.unstocked()).where((c) => c.id == config.itemId).firstOrNull;
      if (named != null) turnedOn.added.add(StockItem(id: named.id, name: named.name, unit: unit));
    }
    return (id: config.itemId, revision: revision, replayed: false);
  }

  /// #4402 -- what a new item needs beside its stock settings: a service of the Demo's catalogue and a home in its
  /// registry, wired by the Demo's kit. Without them a new item is refused as a malformed request.
  ({
    Future<String> Function(String name, int priceCents, String? vatRateId, String requestId) service,
    Future<void> Function(String itemId, String placeId, String requestId) home,
  })? newItems;

  /// The items made by request id: a retry answers the item it first made.
  final Map<String, StockSaved> _made = {};

  @override
  Future<StockSaved> createItem(String workspaceId, NewStockItemDraft draft, String requestId) async {
    final steps = newItems;
    if (!_mine(workspaceId) || steps == null) throw const StockConfigRefused('request', StockRefusal.malformed);
    if (_made[requestId] case final done?) return (id: done.id, revision: done.revision, replayed: true);
    // the server makes the three in one transaction: what it would refuse is refused before anything is made
    if (draft.homeLocationId case final home?) {
      final place = _places[home];
      if (place == null || place.virtual || !place.active) throw const StockConfigRefused('home_location_id', StockRefusal.homeInvalid);
    }
    final id = await steps.service(draft.name, draft.priceCents, draft.vatRateId, '$requestId:service');
    final saved = await saveItem(
      workspaceId,
      StockItemConfig(
        itemId: id, revision: (await item(workspaceId, id))?.revision ?? 1, stockable: true, purchasable: true, sellable: true,
        inventoryUnit: draft.inventoryUnit, tracking: 'none', shelfLifeDays: null, units: const [],
        codes: [if (draft.barcode case final code?) StockCodeDraft(code: code, kind: 'own')],
      ),
      '$requestId:settings',
    );
    if (draft.homeLocationId case final home?) await steps.home(id, home, '$requestId:home');
    return _made[requestId] = (id: id, revision: saved.revision, replayed: false);
  }

  @override
  Future<StockSaved> savePlace(
    String workspaceId, {
    required StockPlaceDraft place,
    required String requestId,
    String? placeId,
    int? expectedRevision,
  }) async {
    final body = place.toJson();
    if (!_mine(workspaceId)) throw const StockConfigRefused('place', StockRefusal.locationParentForeign);
    final old = placeId == null ? null : _places[placeId];
    if (placeId != null && old == null) throw const StockConfigRefused('place', StockRefusal.locationParentForeign);
    if (old != null && old.revision != expectedRevision) throw const StockConfigStale();
    final code = (body['code'] as String? ?? '').trim();
    final problems = checkStockPlace(code: code, name: body['name'] as String? ?? '', barcode: body['barcode'] as String? ?? '');
    if (problems.entries.firstOrNull case final first?) throw StockConfigRefused(first.key, first.value);
    final parentId = body.containsKey('parent_id') ? body['parent_id'] as String? : old?.parentId;
    final kind = body['kind'] as String? ?? old?.kind ?? 'shelf';
    final pick = body.containsKey('pick_role') ? body['pick_role'] as String? : old?.pickRole;
    final refused = stockPlaceSaveRefusal(_places, code: code, kind: kind, parentId: parentId, pickRole: pick, old: old);
    if (refused != null) throw refused;
    final id = placeId ?? 'demo-place-new-${_next++}';
    final revision = (old?.revision ?? 0) + 1;
    _places[id] = StockPlaceConfig(
      id: id, revision: revision, kind: kind, code: code,
      name: body['name'] as String? ?? '', barcode: body['barcode'] as String?,
      parentId: parentId, active: body['active'] as bool? ?? true, virtual: false,
      receivesFromSuppliers: stockKindLevel(kind) != 1 || (body['receives_from_suppliers'] as bool? ?? true),
      pickRole: stockKindLevel(kind) == 1 ? null : pick,
      addressPath: stockAddressUnder(_places, parentId, code),
    );
    stockReaddressBelow(_places, id);
    return (id: id, revision: revision, replayed: false);
  }

  final Map<String, StockDimension> _dimensions = {
    'demo-dim-colour': const StockDimension(
      id: 'demo-dim-colour', revision: 1, name: 'Colour', active: true,
      values: [
        StockDimensionValue(id: 'demo-val-red', label: 'Red', active: true),
        StockDimensionValue(id: 'demo-val-blue', label: 'Blue', active: true),
      ],
    ),
    'demo-dim-size': const StockDimension(
      id: 'demo-dim-size', revision: 1, name: 'Size', active: true,
      values: [
        StockDimensionValue(id: 'demo-val-m', label: 'M', active: true),
        StockDimensionValue(id: 'demo-val-l', label: 'L', active: true),
      ],
    ),
  };

  final Map<String, List<StockVariant>> _variants = {};
  final Map<String, SupplierItemMapping> _mappings = {
    'demo-map-1': const SupplierItemMapping(
      id: 'demo-map-1', revision: 1, supplierId: 'demo-supplier-1', itemId: 'demo-item-mugs',
      variantId: null, articleRef: 'MUG-BOX-6', purchaseUnit: 'box', active: true,
    ),
  };

  @override
  Future<List<StockDimension>> dimensions(String workspaceId) async =>
      _mine(workspaceId) ? _dimensions.values.toList() : const [];

  @override
  Future<List<StockVariant>> variants(String workspaceId, String itemId) async =>
      _mine(workspaceId) ? (_variants[itemId] ?? const []) : const [];

  @override
  Future<List<StockSupplierRef>> suppliers(String workspaceId) async => _mine(workspaceId)
      ? const [StockSupplierRef(id: 'demo-supplier-1', name: 'Textiles Nord'), StockSupplierRef(id: 'demo-supplier-2', name: 'Café Import')]
      : const [];

  @override
  Future<List<SupplierItemMapping>> mappings(String workspaceId) async =>
      _mine(workspaceId) ? _mappings.values.toList() : const [];

  @override
  Future<StockSaved> saveDimension(
    String workspaceId, {
    required StockDimension dimension,
    required String requestId,
    String? dimensionId,
    int? expectedRevision,
  }) async {
    final body = dimension.toSave();
    final old = dimensionId == null ? null : _dimensions[dimensionId];
    if (dimensionId != null && old == null) throw const StockConfigRefused('request', StockRefusal.malformed);
    if (old != null && old.revision != expectedRevision) throw const StockConfigStale();
    final name = (body['name'] as String? ?? old?.name ?? '').trim();
    final raw = [for (final v in (body['values'] as List?) ?? const []) StockDimensionValue.fromJson(v)];
    final others = [for (final d in _dimensions.values) if (d.id != dimensionId) d.name];
    final refused = stockDimensionRefusal(name, others, [for (final v in raw) v.label]);
    if (refused != null) throw refused;
    final values = [for (final v in raw) StockDimensionValue(id: v.id ?? 'demo-val-${_next++}', label: v.label.trim(), active: v.active)];
    final id = dimensionId ?? 'demo-dim-${_next++}';
    final revision = (old?.revision ?? 0) + 1;
    _dimensions[id] = StockDimension(
      id: id, revision: revision, name: name, active: body['active'] as bool? ?? true, values: values,
    );
    return (id: id, revision: revision, replayed: false);
  }

  @override
  Future<StockSaved> saveVariants(
    String workspaceId,
    String itemId, {
    required List<StockVariant> variants,
    required int expectedRevision,
    required String requestId,
  }) async {
    final item = _mine(workspaceId) ? _items[itemId] : null;
    if (item == null) throw const StockConfigRefused('item_id', StockRefusal.itemForeign);
    if (item.revision != expectedRevision) throw const StockConfigStale();
    final refused = stockVariantsRefusal(
      [for (final v in variants) (values: v.values, priceCents: v.priceCents)],
      (d) => _dimensions[d]?.values.map((x) => x.id).whereType<String>().toSet(),
    );
    if (refused != null) throw refused;
    final saved = [
      for (final v in variants)
        StockVariant(
          id: v.id ?? 'demo-variant-${_next++}', values: v.values, priceCents: v.priceCents,
          active: v.active, label: _labelOf(v.values),
        ),
    ];
    _variants[itemId] = saved;
    final revision = item.revision + 1;
    _items[itemId] = StockItemConfig(
      itemId: itemId, revision: revision, stockable: item.stockable, purchasable: item.purchasable,
      sellable: item.sellable, inventoryUnit: item.inventoryUnit, tracking: item.tracking,
      shelfLifeDays: item.shelfLifeDays, units: item.units, codes: item.codes,
    );
    return (id: itemId, revision: revision, replayed: false);
  }

  String _labelOf(Map<String, String> values) {
    final parts = <(String, String)>[
      for (final d in _dimensions.values)
        if (values[d.id] case final valueId?)
          (d.name, d.values.where((v) => v.id == valueId).map((v) => v.label).firstOrNull ?? ''),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return parts.map((p) => '${p.$1}: ${p.$2}').join(' · ');
  }

  @override
  Future<StockSaved> saveMapping(
    String workspaceId, {
    required SupplierMappingDraft mapping,
    required String requestId,
    String? mappingId,
    int? expectedRevision,
  }) async {
    final body = mapping.toJson();
    final old = mappingId == null ? null : _mappings[mappingId];
    if (mappingId != null && old == null) throw const StockConfigRefused('request', StockRefusal.malformed);
    if (old != null && old.revision != expectedRevision) throw const StockConfigStale();
    final supplier = body['supplier_id'] as String? ?? old?.supplierId;
    final itemId = body['item_id'] as String? ?? old?.itemId;
    final ref = (body['article_ref'] as String? ?? old?.articleRef ?? '').trim();
    final unit = body.containsKey('purchase_unit') ? body['purchase_unit'] as String? : old?.purchaseUnit;
    final refused = supplierMappingRefusal(
      supplierKnown: supplier != null && (await suppliers(workspaceId)).any((s) => s.id == supplier),
      item: itemId == null ? null : _items[itemId],
      articleRef: ref,
      purchaseUnit: unit,
      refTaken: _mappings.values.any((m) => m.supplierId == supplier && m.articleRef == ref && m.id != mappingId),
    );
    if (refused != null) throw refused;
    final id = mappingId ?? 'demo-map-${_next++}';
    final revision = (old?.revision ?? 0) + 1;
    _mappings[id] = SupplierItemMapping(
      id: id, revision: revision, supplierId: supplier!, itemId: itemId!,
      variantId: body.containsKey('variant_id') ? body['variant_id'] as String? : old?.variantId,
      articleRef: ref, purchaseUnit: unit, active: body['active'] as bool? ?? true,
    );
    return (id: id, revision: revision, replayed: false);
  }
}
