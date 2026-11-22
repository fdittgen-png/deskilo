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
import 'package:deskilo/features/stock/domain/stock_variants.dart';

/// The in-memory configuration of the reference business.
class DemoStockConfigCommands implements StockConfigCommands {
  DemoStockConfigCommands(this.workspaceId);

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
      units: [StockUnitDraft(unit: 'box', factorNum: 6, factorDen: 1, defaultPurchase: true)],
      codes: [StockCodeDraft(code: 'MUG-001', kind: 'own')],
    ),
    'demo-item-shirt': const StockItemConfig(
      itemId: 'demo-item-shirt', revision: 1, stockable: true, purchasable: true, sellable: true,
      inventoryUnit: 'piece', tracking: 'none', shelfLifeDays: null, units: [], codes: [],
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
      barcode: null, parentId: null, active: true, virtual: false,
    ),
    'demo-place-shelf': const StockPlaceConfig(
      id: 'demo-place-shelf', revision: 1, kind: 'shelf', code: 'SHELF-A', name: 'Shelf A',
      barcode: null, parentId: 'demo-place-main', active: true, virtual: false,
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
  };

  /// The items the Demo's movements name: their unit and tracking are fixed.
  static const _withHistory = {'demo-item-beans', 'demo-item-milk', 'demo-item-mugs', 'demo-item-syrup'};

  int _next = 1;

  bool _mine(String id) => id == workspaceId;

  @override
  Future<StockItemConfig?> item(String workspaceId, String itemId) async =>
      _mine(workspaceId) ? _items[itemId] : null;

  @override
  Future<List<StockPlaceConfig>> places(String workspaceId) async =>
      _mine(workspaceId) ? _places.values.toList() : const [];

  @override
  Future<StockSaved> saveItem(String workspaceId, StockItemConfig config, String requestId) async {
    final old = _mine(workspaceId) ? _items[config.itemId] : null;
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
    _items[config.itemId] = StockItemConfig(
      itemId: config.itemId, revision: revision, stockable: config.stockable,
      purchasable: config.purchasable, sellable: config.sellable,
      inventoryUnit: old.inventoryUnit, tracking: config.tracking, shelfLifeDays: config.shelfLifeDays,
      units: config.units, codes: config.codes,
    );
    return (id: config.itemId, revision: revision, replayed: false);
  }

  @override
  Future<StockSaved> savePlace(
    String workspaceId, {
    required Map<String, Object?> place,
    required String requestId,
    String? placeId,
    int? expectedRevision,
  }) async {
    if (!_mine(workspaceId)) throw const StockConfigRefused('place', 'location_parent_foreign');
    final old = placeId == null ? null : _places[placeId];
    if (placeId != null && old == null) throw const StockConfigRefused('place', 'location_parent_foreign');
    if (old != null && old.revision != expectedRevision) throw const StockConfigStale();
    final code = (place['code'] as String? ?? '').trim();
    final problems = checkStockPlace(code: code, name: place['name'] as String? ?? '', barcode: place['barcode'] as String? ?? '');
    if (problems.isNotEmpty) {
      final first = problems.entries.first;
      throw StockConfigRefused(first.key, first.value);
    }
    if (_places.values.any((p) => p.code == code && p.id != placeId)) {
      throw const StockConfigRefused('code', 'code_duplicate');
    }
    if (place['parent_id'] != null && place['parent_id'] == placeId) {
      throw const StockConfigRefused('parent_id', 'location_cycle');
    }
    final id = placeId ?? 'demo-place-new-${_next++}';
    final revision = (old?.revision ?? 0) + 1;
    _places[id] = StockPlaceConfig(
      id: id, revision: revision, kind: place['kind'] as String? ?? 'shelf', code: code,
      name: place['name'] as String? ?? '', barcode: place['barcode'] as String?,
      parentId: place['parent_id'] as String?, active: place['active'] as bool? ?? true, virtual: false,
    );
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
    required Map<String, Object?> dimension,
    required String requestId,
    String? dimensionId,
    int? expectedRevision,
  }) async {
    final old = dimensionId == null ? null : _dimensions[dimensionId];
    if (dimensionId != null && old == null) throw const StockConfigRefused('request', 'malformed');
    if (old != null && old.revision != expectedRevision) throw const StockConfigStale();
    final name = (dimension['name'] as String? ?? old?.name ?? '').trim();
    if (name.isEmpty || name.length > 60) throw const StockConfigRefused('name', 'name_malformed');
    if (_dimensions.values.any((d) => d.name == name && d.id != dimensionId)) {
      throw const StockConfigRefused('name', 'name_duplicate');
    }
    final raw = (dimension['values'] as List?) ?? const [];
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
      id: id, revision: revision, name: name, active: dimension['active'] as bool? ?? true, values: values,
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
    required Map<String, Object?> mapping,
    required String requestId,
    String? mappingId,
    int? expectedRevision,
  }) async {
    final old = mappingId == null ? null : _mappings[mappingId];
    if (mappingId != null && old == null) throw const StockConfigRefused('request', 'malformed');
    if (old != null && old.revision != expectedRevision) throw const StockConfigStale();
    final supplier = mapping['supplier_id'] as String? ?? old?.supplierId;
    final itemId = mapping['item_id'] as String? ?? old?.itemId;
    final ref = (mapping['article_ref'] as String? ?? old?.articleRef ?? '').trim();
    final unit = mapping.containsKey('purchase_unit') ? mapping['purchase_unit'] as String? : old?.purchaseUnit;
    await _checkMapping(workspaceId, mappingId, supplier, itemId, ref, unit);
    final id = mappingId ?? 'demo-map-${_next++}';
    final revision = (old?.revision ?? 0) + 1;
    _mappings[id] = SupplierItemMapping(
      id: id, revision: revision, supplierId: supplier!, itemId: itemId!,
      variantId: mapping.containsKey('variant_id') ? mapping['variant_id'] as String? : old?.variantId,
      articleRef: ref, purchaseUnit: unit, active: mapping['active'] as bool? ?? true,
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
