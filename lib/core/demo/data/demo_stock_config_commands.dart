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

  @override
  Future<StockSaved> saveItem(String workspaceId, StockItemConfig config, String requestId) async {
    final old = _mine(workspaceId) ? await item(workspaceId, config.itemId) : null;
    if (old == null) throw const StockConfigRefused('item_id', 'item_foreign');
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

  @override
  Future<StockSaved> savePlace(
    String workspaceId, {
    required StockPlaceDraft place,
    required String requestId,
    String? placeId,
    int? expectedRevision,
  }) async {
    final body = place.toJson();
    if (!_mine(workspaceId)) throw const StockConfigRefused('place', 'location_parent_foreign');
    final old = placeId == null ? null : _places[placeId];
    if (placeId != null && old == null) throw const StockConfigRefused('place', 'location_parent_foreign');
    if (old != null && old.revision != expectedRevision) throw const StockConfigStale();
    final (:code, :parentId, :kind, :pick) = _checkedPlace(body, old, placeId);
    final id = placeId ?? 'demo-place-new-${_next++}';
    final revision = (old?.revision ?? 0) + 1;
    _places[id] = StockPlaceConfig(
      id: id, revision: revision, kind: kind, code: code,
      name: body['name'] as String? ?? '', barcode: body['barcode'] as String?,
      parentId: parentId, active: body['active'] as bool? ?? true, virtual: false,
      receivesFromSuppliers: stockKindLevel(kind) != 1 || (body['receives_from_suppliers'] as bool? ?? true),
      pickRole: stockKindLevel(kind) == 1 ? null : pick,
      addressPath: _pathOf(parentId, code),
    );
    _recompose(id);
    return (id: id, revision: revision, replayed: false);
  }

  /// What the server refuses before it writes a place: a code or name that is malformed or taken
  /// among its siblings, a parent that is itself, a level under the wrong level, an unknown use.
  ({String code, String? parentId, String kind, String? pick}) _checkedPlace(
    Map<String, Object?> place,
    StockPlaceConfig? old,
    String? placeId,
  ) {
    final code = (place['code'] as String? ?? '').trim();
    final problems = checkStockPlace(code: code, name: place['name'] as String? ?? '', barcode: place['barcode'] as String? ?? '');
    if (problems.isNotEmpty) {
      final first = problems.entries.first;
      throw StockConfigRefused(first.key, first.value);
    }
    final parentId = place.containsKey('parent_id') ? place['parent_id'] as String? : old?.parentId;
    final kind = place['kind'] as String? ?? old?.kind ?? 'shelf';
    if (_places.values.any((p) => p.code == code && p.parentId == parentId && p.id != placeId)) {
      throw const StockConfigRefused('code', 'code_duplicate');
    }
    if (parentId != null && parentId == placeId) {
      throw const StockConfigRefused('parent_id', 'location_cycle');
    }
    _checkLevel(kind, old, parentId);
    final pick = place.containsKey('pick_role') ? place['pick_role'] as String? : old?.pickRole;
    if (pick != null && pick != 'picking' && pick != 'reserve') {
      throw const StockConfigRefused('pick_role', 'pick_role_unknown');
    }
    return (code: code, parentId: parentId, kind: kind, pick: pick);
  }

  /// The server's level rule: checked when a place is made or its kind or parent changes.
  void _checkLevel(String kind, StockPlaceConfig? old, String? parentId) {
    final level = stockKindLevel(kind);
    if (level == null || (old != null && kind == old.kind && parentId == old.parentId)) return;
    if (parentId == null) {
      if (level != 1) throw const StockConfigRefused('parent_id', 'level_parent_missing');
    } else if (stockKindLevel(_places[parentId]?.kind ?? '') != level - 1) {
      throw const StockConfigRefused('parent_id', 'level_parent_wrong');
    }
  }

  String _pathOf(String? parentId, String code) =>
      parentId == null ? code : '${_places[parentId]?.addressPath ?? ''}$stockAddressJoint$code';

  /// Everything below [parentId] takes the address of its parent again, as the server's trigger does.
  void _recompose(String parentId) {
    for (final c in _places.values.where((p) => p.parentId == parentId).toList()) {
      _places[c.id] = StockPlaceConfig(
        id: c.id, revision: c.revision, kind: c.kind, code: c.code, name: c.name, barcode: c.barcode,
        parentId: c.parentId, active: c.active, virtual: c.virtual,
        receivesFromSuppliers: c.receivesFromSuppliers, pickRole: c.pickRole,
        addressPath: _pathOf(c.parentId, c.code),
      );
      _recompose(c.id);
    }
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
    if (dimensionId != null && old == null) throw const StockConfigRefused('request', 'malformed');
    if (old != null && old.revision != expectedRevision) throw const StockConfigStale();
    final name = (body['name'] as String? ?? old?.name ?? '').trim();
    if (name.isEmpty || name.length > 60) throw const StockConfigRefused('name', 'name_malformed');
    if (_dimensions.values.any((d) => d.name == name && d.id != dimensionId)) {
      throw const StockConfigRefused('name', 'name_duplicate');
    }
    final raw = (body['values'] as List?) ?? const [];
    final values = <StockDimensionValue>[];
    for (var i = 0; i < raw.length; i++) {
      final v = StockDimensionValue.fromJson(raw[i]);
      if (v.label.trim().isEmpty) throw StockConfigRefused('values[$i].label', 'name_malformed');
      if (values.any((x) => x.label == v.label.trim())) throw StockConfigRefused('values[$i].label', 'name_duplicate');
      values.add(StockDimensionValue(id: v.id ?? 'demo-val-${_next++}', label: v.label.trim(), active: v.active));
    }
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
    if (item == null) throw const StockConfigRefused('item_id', 'item_foreign');
    if (item.revision != expectedRevision) throw const StockConfigStale();
    final seen = <String>{};
    final saved = <StockVariant>[];
    for (var i = 0; i < variants.length; i++) {
      final v = variants[i];
      if (v.values.isEmpty) throw StockConfigRefused('variants[$i].values', 'variant_values_missing');
      if ((v.priceCents ?? 0) < 0) throw StockConfigRefused('variants[$i].price_cents', 'price_invalid');
      for (final e in v.values.entries) {
        if (_dimensions[e.key]?.values.any((x) => x.id == e.value) != true) {
          throw StockConfigRefused('variants[$i].values', 'value_foreign');
        }
      }
      final canonical = (v.values.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}:${e.value}').join(',');
      if (!seen.add(canonical)) throw StockConfigRefused('variants[$i].values', 'variant_combination_duplicate');
      saved.add(StockVariant(
        id: v.id ?? 'demo-variant-${_next++}', values: v.values, priceCents: v.priceCents,
        active: v.active, label: _labelOf(v.values),
      ));
    }
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
    if (mappingId != null && old == null) throw const StockConfigRefused('request', 'malformed');
    if (old != null && old.revision != expectedRevision) throw const StockConfigStale();
    final supplier = body['supplier_id'] as String? ?? old?.supplierId;
    final itemId = body['item_id'] as String? ?? old?.itemId;
    final ref = (body['article_ref'] as String? ?? old?.articleRef ?? '').trim();
    final unit = body.containsKey('purchase_unit') ? body['purchase_unit'] as String? : old?.purchaseUnit;
    await _checkMapping(workspaceId, mappingId, supplier, itemId, ref, unit);
    final id = mappingId ?? 'demo-map-${_next++}';
    final revision = (old?.revision ?? 0) + 1;
    _mappings[id] = SupplierItemMapping(
      id: id, revision: revision, supplierId: supplier!, itemId: itemId!,
      variantId: body.containsKey('variant_id') ? body['variant_id'] as String? : old?.variantId,
      articleRef: ref, purchaseUnit: unit, active: body['active'] as bool? ?? true,
    );
    return (id: id, revision: revision, replayed: false);
  }

  /// What the server refuses of a supplier article, in the order it refuses it.
  Future<void> _checkMapping(String workspaceId, String? mappingId, String? supplier, String? itemId, String ref, String? unit) async {
    if (supplier == null || !(await suppliers(workspaceId)).any((s) => s.id == supplier)) {
      throw const StockConfigRefused('supplier_id', 'supplier_foreign');
    }
    final item = itemId == null ? null : _items[itemId];
    if (item == null) throw const StockConfigRefused('item_id', 'item_foreign');
    if (ref.isEmpty || ref.length > 80) throw const StockConfigRefused('article_ref', 'code_malformed');
    if (unit != null && !item.units.any((u) => u.unit == unit)) {
      throw const StockConfigRefused('purchase_unit', 'unit_not_of_item');
    }
    if (_mappings.values.any((m) => m.supplierId == supplier && m.articleRef == ref && m.id != mappingId)) {
      throw const StockConfigRefused('article_ref', 'mapping_duplicate');
    }
  }
}
