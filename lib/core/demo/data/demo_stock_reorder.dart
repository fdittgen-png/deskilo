// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4294 (G8, client) -- the Demo's reorder points and what they say, for the reference business:
// two shop items below their point at the store site (the beans and the syrup), the mugs and the
// milk above theirs. "Low" is read from the ONE Demo ledger, so a delivery put away or a movement
// made on the Transfers page lifts or lowers it; the replenishment list groups what is low by the
// supplier whose article is preferred (the beans), and the syrup has none ("no supplier chosen").
// A draft is kept here, once per request: nothing is ordered, priced or sent.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_config_commands.dart';
import 'package:deskilo/features/stock/domain/stock_ledger.dart';
import 'package:deskilo/features/stock/domain/stock_reorder.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'demo_stock_ledger.dart';

class DemoStockReorder implements StockReorder {
  DemoStockReorder(this._workspaceId, this._ledger, this._config);

  final String _workspaceId;
  final DemoStockLedger _ledger;
  final StockConfigCommands _config;

  static const _site = 'demo-place-main';

  /// The business's points, as the server holds them: the beans and the syrup are below theirs, the
  /// milk and the mugs above. Editable from the Reorder page (the server's rules).
  final _points = <String, StockReorderPoint>{
    'demo-point-demo-item-beans': StockReorderPoint(
      id: 'demo-point-demo-item-beans', revision: 1, itemId: 'demo-item-beans', siteId: _site, active: true,
      reorderPoint: ExactQuantity.parse('20'), reorderQuantity: ExactQuantity.parse('25'),
    ),
    'demo-point-demo-item-syrup': StockReorderPoint(
      id: 'demo-point-demo-item-syrup', revision: 1, itemId: 'demo-item-syrup', siteId: _site, active: true,
      reorderPoint: ExactQuantity.parse('5'), targetQuantity: ExactQuantity.parse('20'),
    ),
    'demo-point-demo-item-milk': StockReorderPoint(
      id: 'demo-point-demo-item-milk', revision: 1, itemId: 'demo-item-milk', siteId: _site, active: true,
      reorderPoint: ExactQuantity.parse('10'), reorderQuantity: ExactQuantity.parse('24'),
    ),
    'demo-point-demo-item-mugs': StockReorderPoint(
      id: 'demo-point-demo-item-mugs', revision: 1, itemId: 'demo-item-mugs', siteId: _site, active: true,
      reorderPoint: ExactQuantity.parse('20'), reorderQuantity: ExactQuantity.parse('48'),
    ),
  };
  int _next = 1;

  /// Item id -> (supplier, its article, the purchase unit): the preferred article.
  static const _preferred = <String, (String, String, String, String)>{
    'demo-item-beans': ('demo-supplier-2', 'Café Import', 'BEANS-5KG', 'kg'),
  };

  final _drafts = <String, ReplenishmentDraft>{};

  @override
  Future<List<StockReorderPoint>> points(String workspaceId) async =>
      workspaceId == _workspaceId ? _points.values.toList() : const [];

  @override
  Future<StockSaved> savePoint(
    String workspaceId, {
    required StockReorderPointDraft point,
    required String requestId,
    String? pointId,
    int? expectedRevision,
  }) async {
    final body = point.toJson();
    if (workspaceId != _workspaceId) throw const StockConfigRefused('item_id', StockRefusal.itemForeign);
    final old = pointId == null ? null : _points[pointId];
    if (pointId != null && old == null) throw const StockConfigRefused('point', StockRefusal.malformed);
    if (old != null && old.revision != expectedRevision) throw const StockConfigStale();
    final (:item, :variant, :site) = await _targetOf(body, old);
    final read = StockLedger.reorderQuantityOf(body, 'reorder_point', old?.reorderPoint);
    final quantity = StockLedger.reorderQuantityOf(body, 'reorder_quantity', old?.reorderQuantity);
    final target = StockLedger.reorderQuantityOf(body, 'target_quantity', old?.targetQuantity);
    final level = StockLedger.reorderRule(read, quantity, target);
    if (_points.values.any((p) => p.itemId == item && p.variantId == variant && p.siteId == site && p.id != pointId)) {
      throw const StockConfigRefused('item_id', StockRefusal.pointTwice);
    }
    final id = pointId ?? 'demo-point-new-${_next++}';
    final revision = (old?.revision ?? 0) + 1;
    _points[id] = StockReorderPoint(
      id: id, revision: revision, itemId: item, variantId: variant, siteId: site, reorderPoint: level,
      reorderQuantity: quantity, targetQuantity: target, active: body['active'] as bool? ?? old?.active ?? true,
    );
    return (id: id, revision: revision, replayed: false);
  }

  /// The item, variant and site a payload names (a point that exists keeps its own), as the server
  /// checks them.
  Future<({String item, String? variant, String site})> _targetOf(Map<String, Object?> point, StockReorderPoint? old) async {
    final item = point['item_id'] as String? ?? old?.itemId;
    final variant = point.containsKey('variant_id') ? point['variant_id'] as String? : old?.variantId;
    final site = point['site_id'] as String? ?? old?.siteId;
    if (item == null || !DemoStockLedger.items.any((i) => i.id == item)) {
      throw const StockConfigRefused('item_id', StockRefusal.itemForeign);
    }
    final places = await _config.places(_workspaceId);
    final siteOk = places.any((p) => p.id == site && p.parentId == null && !p.virtual && p.active && p.kind != 'in_transit');
    if (site == null || !siteOk) throw const StockConfigRefused('site_id', StockRefusal.siteUnknown);
    if (old != null && (item != old.itemId || variant != old.variantId || site != old.siteId)) {
      throw const StockConfigRefused('item_id', StockRefusal.pointFixed);
    }
    return (item: item, variant: variant, site: site);
  }

  @override
  Future<List<StockLowRow>> low(String workspaceId, {String? siteId}) async {
    if (workspaceId != _workspaceId || (siteId != null && siteId != _site)) return const [];
    final rows = <StockLowRow>[];
    for (final p in _points.values) {
      final item = DemoStockLedger.items.where((i) => i.id == p.itemId).firstOrNull;
      if (item == null || !p.active || p.variantId != null || p.siteId != _site) continue;
      final held = _ledger.core.heldInSite(item.id, _site);
      if (held.compareTo(p.reorderPoint) > 0) continue;
      final ExactQuantity? proposed = p.reorderQuantity ?? (p.targetQuantity == null ? null : p.targetQuantity! - held);
      rows.add(
        StockLowRow(
          pointId: p.id,
          itemId: item.id,
          itemName: item.name,
          unit: item.unit,
          siteId: _site,
          siteCode: 'MAIN',
          onHand: held,
          reorderPoint: p.reorderPoint,
          proposed: proposed,
        ),
      );
    }
    return rows;
  }

  @override
  Future<ReplenishmentList> replenishment(String workspaceId, {String? siteId}) async {
    final rows = (await low(workspaceId, siteId: siteId)).where((r) => (r.proposed?.compareTo(ExactQuantity.zero) ?? 0) > 0);
    final groups = <String, List<ReplenishmentLine>>{};
    final names = <String, String>{};
    final gaps = <ReplenishmentGap>[];
    for (final r in rows) {
      final article = _preferred[r.itemId];
      if (article == null) {
        gaps.add(
          ReplenishmentGap(
            itemId: r.itemId,
            itemName: r.itemName,
            siteCode: r.siteCode,
            unit: r.unit,
            quantity: r.proposed!,
          ),
        );
        continue;
      }
      names[article.$1] = article.$2;
      (groups[article.$1] ??= []).add(
        ReplenishmentLine(
          pointId: r.pointId,
          itemId: r.itemId,
          itemName: r.itemName,
          siteCode: r.siteCode,
          articleRef: article.$3,
          unit: article.$4,
          quantity: r.proposed!,
        ),
      );
    }
    return ReplenishmentList(
      groups: [
        for (final e in groups.entries) ReplenishmentGroup(supplierId: e.key, supplierName: names[e.key]!, lines: e.value),
      ],
      noSupplier: gaps,
    );
  }

  @override
  Future<ReplenishmentDraft> createDraft(
    String workspaceId, {
    required String supplierId,
    required List<ReplenishmentLine> lines,
    required String requestId,
  }) async {
    if (workspaceId != _workspaceId || lines.isEmpty) {
      throw const StockConfigRefused('lines', StockRefusal.malformed);
    }
    final known = lines.every((l) => _preferred[l.itemId]?.$1 == supplierId);
    if (!known) throw const StockConfigRefused('lines', StockRefusal.mappingUnknown);
    return _drafts.putIfAbsent(requestId, () => (orderId: 'demo-draft-${_drafts.length + 1}', number: 'DRAFT-${_drafts.length + 1}'));
  }
}
