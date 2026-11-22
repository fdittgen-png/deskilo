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
import 'package:deskilo/features/stock/domain/stock_reorder.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'demo_stock_ledger.dart';

class DemoStockReorder implements StockReorder {
  DemoStockReorder(this._workspaceId, this._ledger, this._config);

  final String _workspaceId;
  final DemoStockLedger _ledger;
  final StockConfigCommands _config;

  static const _site = 'demo-place-main';

  /// Item id -> (reorder point, the quantity to order, or null for "up to" [target]).
  static const _points = <String, ({String point, String? quantity, String? target})>{
    'demo-item-beans': (point: '20', quantity: '25', target: null),
    'demo-item-syrup': (point: '5', quantity: null, target: '20'),
    'demo-item-milk': (point: '10', quantity: '24', target: null),
    'demo-item-mugs': (point: '20', quantity: '48', target: null),
  };

  /// Item id -> (supplier, its article, the purchase unit): the preferred article.
  static const _preferred = <String, (String, String, String, String)>{
    'demo-item-beans': ('demo-supplier-2', 'Café Import', 'BEANS-5KG', 'kg'),
  };

  final _drafts = <String, ReplenishmentDraft>{};

  Future<Set<String>> _siteTree() async {
    final places = await _config.places(_workspaceId);
    final out = {_site};
    var grew = true;
    while (grew) {
      grew = false;
      for (final p in places) {
        if (p.parentId != null && out.contains(p.parentId) && out.add(p.id)) grew = true;
      }
    }
    return out;
  }

  @override
  Future<List<StockLowRow>> low(String workspaceId, {String? siteId}) async {
    if (workspaceId != _workspaceId || (siteId != null && siteId != _site)) return const [];
    final tree = await _siteTree();
    final onHand = await _ledger.onHand();
    final rows = <StockLowRow>[];
    for (final item in DemoStockLedger.items) {
      final p = _points[item.id];
      if (p == null) continue;
      var held = ExactQuantity.zero;
      for (final r in onHand) {
        if (r.itemId == item.id && r.variantId == null && tree.contains(r.locationId)) held = held + r.quantity;
      }
      final point = ExactQuantity.parse(p.point);
      if (held.compareTo(point) > 0) continue;
      final ExactQuantity? proposed = p.quantity != null
          ? ExactQuantity.parse(p.quantity!)
          : p.target == null
          ? null
          : ExactQuantity.parse(p.target!) - held;
      rows.add(
        StockLowRow(
          pointId: 'demo-point-${item.id}',
          itemId: item.id,
          itemName: item.name,
          unit: item.unit,
          siteId: _site,
          siteCode: 'MAIN',
          onHand: held,
          reorderPoint: point,
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
      throw const StockConfigRefused('lines', 'malformed');
    }
    final known = lines.every((l) => _preferred[l.itemId]?.$1 == supplierId);
    if (!known) throw const StockConfigRefused('lines', 'mapping_unknown');
    return _drafts.putIfAbsent(requestId, () => (orderId: 'demo-draft-${_drafts.length + 1}', number: 'DRAFT-${_drafts.length + 1}'));
  }
}
