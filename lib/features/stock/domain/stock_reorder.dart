// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4294 (G8, client) -- what is low and what to order. A reorder point is set per item (or variant)
// and per site; "low" is computed by the server from the ledger, exact in the item's inventory
// unit. The replenishment list groups what is low by the supplier whose article is preferred for it,
// in that article's purchase unit; a DRAFT purchase order is made from a group, never an order
// that was sent or priced.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// One item (or variant) at one site at or below its reorder point.
class StockLowRow {
  const StockLowRow({
    required this.pointId,
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.siteId,
    required this.siteCode,
    required this.onHand,
    required this.reorderPoint,
    this.variantId,
    this.proposed,
    this.since,
  });

  final String pointId;
  final String itemId;
  final String itemName;
  final String unit;
  final String? variantId;
  final String siteId;
  final String siteCode;
  final ExactQuantity onHand;
  final ExactQuantity reorderPoint;

  /// What to order, in the inventory unit; null when the point names neither a quantity nor a target.
  final ExactQuantity? proposed;

  /// Since when it has been low (the open alert's start); null when the alert is not read.
  final DateTime? since;

  factory StockLowRow.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_low_v1');
    final proposed = r.stringOrNull('proposed');
    return StockLowRow(
      pointId: r.string('point_id'),
      itemId: r.string('item_id'),
      itemName: r.stringOr('item_name'),
      unit: r.stringOr('unit'),
      variantId: r.stringOrNull('variant_id'),
      siteId: r.string('site_id'),
      siteCode: r.stringOr('site_code'),
      onHand: ExactQuantity.parse(r.string('on_hand')),
      reorderPoint: ExactQuantity.parse(r.string('reorder_point')),
      proposed: proposed == null ? null : ExactQuantity.parse(proposed),
      since: r.dateTimeOrNull('since'),
    );
  }
}

/// One line of a supplier's group: an article to order, in its purchase unit.
class ReplenishmentLine {
  const ReplenishmentLine({
    required this.pointId,
    required this.itemId,
    required this.itemName,
    required this.siteCode,
    required this.unit,
    required this.quantity,
    this.variantId,
    this.articleRef,
  });

  final String pointId;
  final String itemId;
  final String itemName;
  final String? variantId;
  final String siteCode;
  final String? articleRef;

  /// The purchase unit of the preferred article (the inventory unit when it has none).
  final String unit;

  /// In [unit], rounded up to whole units by the server.
  final ExactQuantity quantity;

  factory ReplenishmentLine.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_replenishment_v1');
    return ReplenishmentLine(
      pointId: r.string('point_id'),
      itemId: r.string('item_id'),
      itemName: r.stringOr('item_name'),
      variantId: r.stringOrNull('variant_id'),
      siteCode: r.stringOr('site_code'),
      articleRef: r.stringOrNull('article_ref'),
      unit: r.stringOr('purchase_unit'),
      quantity: ExactQuantity.parse(r.string('quantity')),
    );
  }
}

/// What is low, to order from one supplier.
class ReplenishmentGroup {
  const ReplenishmentGroup({required this.supplierId, required this.supplierName, required this.lines});

  final String supplierId;
  final String supplierName;
  final List<ReplenishmentLine> lines;
}

/// A low item with no preferred supplier article: it cannot be ordered from the list.
class ReplenishmentGap {
  const ReplenishmentGap({
    required this.itemId,
    required this.itemName,
    required this.siteCode,
    required this.unit,
    required this.quantity,
    this.variantId,
  });

  final String itemId;
  final String itemName;
  final String? variantId;
  final String siteCode;
  final String unit;
  final ExactQuantity quantity;

  factory ReplenishmentGap.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_replenishment_v1');
    return ReplenishmentGap(
      itemId: r.string('item_id'),
      itemName: r.stringOr('item_name'),
      variantId: r.stringOrNull('variant_id'),
      siteCode: r.stringOr('site_code'),
      unit: r.stringOr('unit'),
      quantity: ExactQuantity.parse(r.string('inventory_quantity')),
    );
  }
}

/// The replenishment list: the groups by supplier, and what has no preferred supplier article.
class ReplenishmentList {
  const ReplenishmentList({required this.groups, required this.noSupplier});

  final List<ReplenishmentGroup> groups;
  final List<ReplenishmentGap> noSupplier;

  bool get isEmpty => groups.isEmpty && noSupplier.isEmpty;

  factory ReplenishmentList.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_replenishment_v1');
    return ReplenishmentList(
      groups: [
        for (final g in r.requiredList('groups'))
          () {
            final gr = JsonReader.of(g, context: 'stock_replenishment_v1');
            return ReplenishmentGroup(
              supplierId: gr.string('supplier_id'),
              supplierName: gr.stringOr('supplier_name'),
              lines: [for (final l in gr.requiredList('lines')) ReplenishmentLine.fromJson(l)],
            );
          }(),
      ],
      noSupplier: [for (final g in r.requiredList('no_supplier')) ReplenishmentGap.fromJson(g)],
    );
  }
}

/// The draft purchase order a group became.
typedef ReplenishmentDraft = ({String? orderId, String? number});

/// The reads and the one command of the reorder screens.
abstract interface class StockReorder {
  /// Every item at a site at or below its point (all sites when [siteId] is null).
  Future<List<StockLowRow>> low(String workspaceId, {String? siteId});

  /// What to order, by supplier.
  Future<ReplenishmentList> replenishment(String workspaceId, {String? siteId});

  /// A DRAFT purchase order of [lines] from [supplierId]: nothing is ordered, priced or sent. A
  /// request id answers once.
  Future<ReplenishmentDraft> createDraft(
    String workspaceId, {
    required String supplierId,
    required List<ReplenishmentLine> lines,
    required String requestId,
  });
}
