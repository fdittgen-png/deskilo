// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4171 (B) -- the Demo's receiving into stock, behind the same port as the
// server's: a delivery of the Demo's order is recorded and put away in one
// call (both, or neither), or what remains of a recorded delivery is put away
// later, in parts. Nothing is put away that did not arrive, a line that is not
// a stock item is named, a tracked item needs its lot, and a retried request
// answers the same ids. Nothing leaves the process.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/domain/purchase_order_receipt.dart';
import 'package:deskilo/features/stock/domain/put_away_progress.dart' show exactOfReceived;
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_ledger_rules.dart';
import 'package:deskilo/features/stock/domain/stock_receiving.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../demo_replay.dart';
import 'demo_stock_config_commands.dart';
import 'demo_stock_ledger.dart';
import 'demo_stock_tags.dart';
import 'purchase_order_repository.dart';

/// The in-memory put-away of the reference business.
class DemoStockReceivingCommands implements StockReceivingCommands {
  DemoStockReceivingCommands(this.workspaceId, this._orders, this._config, this._ledger, {this.tags});

  /// #4379 -- where the pieces of an item tagged piece by piece are made; null: no item is tagged.
  final DemoStockTags? tags;

  final String workspaceId;
  final FakePurchaseOrderRepository _orders;
  final DemoStockConfigCommands _config;

  /// The ONE Demo ledger: what is put away is what the Stock screen reads.
  final DemoStockLedger _ledger;

  final List<({ReceiptAllocation row, String receiptId})> _rows = [];
  final _answers = Replay<PutAwayResult>();
  int _next = 1;

  static StockConfigRefused _refused(String field, StockRefusal reason) => StockConfigRefused(field, reason);

  bool _mine(String id) => id == workspaceId;

  @override
  Future<List<ReceiptAllocation>> allocations(String workspaceId, String receiptId) async =>
      _mine(workspaceId) ? [for (final r in _rows) if (r.receiptId == receiptId) r.row] : const [];

  @override
  Future<List<ReceiptAllocation>> allocationsOfOrder(String workspaceId, String orderId) async {
    if (!_mine(workspaceId)) return const [];
    final receipts = {for (final r in _orders.receipts) if (r.orderId == orderId) r.id};
    return [for (final r in _rows) if (receipts.contains(r.receiptId)) r.row];
  }

  @override
  Future<PutAwayResult> putAway(
    String workspaceId,
    String receiptId,
    List<PutAwayAllocation> allocations,
    String requestId,
  ) async {
    if (_answers.seen(requestId) case final done?) return (receiptId: done.receiptId, replayed: true, allocations: done.allocations);
    if (!_mine(workspaceId)) throw _refused('receipt', StockRefusal.receiptUnknown);
    final written = await _apply(receiptId, allocations);
    return _answers.keep(requestId, (receiptId: receiptId, replayed: false, allocations: written));
  }

  @override
  Future<PutAwayResult> recordAndPutAway(
    String workspaceId,
    DeliveryDraft delivery,
    List<PutAwayAllocation> allocations,
    String requestId,
  ) async {
    if (_answers.seen(requestId) case final done?) return (receiptId: done.receiptId, replayed: true, allocations: done.allocations);
    if (!_mine(workspaceId)) throw _refused('receipt', StockRefusal.receiptUnknown);
    final i = _orders.orders.indexWhere((o) => o.id == delivery.orderId);
    if (i < 0) throw _refused('request', StockRefusal.malformed);
    final savedOrder = _orders.orders[i];
    final savedReceipts = [..._orders.receipts];
    final order = savedOrder;
    try {
      await _orders.recordReceipt(
        workspaceId,
        'derived-$requestId',
        PurchaseOrderReceiptDraft(
          order: order,
          receivedOn: DateTime.parse(delivery.receivedOn),
          note: delivery.note,
          // the purchase order's own numbers (#4177): the one place a Demo quantity leaves the exact type
          quantities: {for (final l in delivery.lines) l.lineNo: num.parse(l.quantity).toDouble()},
        ),
      );
      final receipt = _orders.receipts.last;
      final written = await _apply(receipt.id, allocations);
      return _answers.keep(requestId, (receiptId: receipt.id, replayed: false, allocations: written));
    } on Object {
      // both halves or neither
      _orders.orders[i] = savedOrder;
      _orders.receipts
        ..clear()
        ..addAll(savedReceipts);
      rethrow;
    }
  }

  Future<List<ReceiptAllocation>> _apply(String receiptId, List<PutAwayAllocation> allocations) async {
    final receipt = _orders.receipts.where((r) => r.id == receiptId).firstOrNull;
    if (receipt == null) throw _refused('receipt', StockRefusal.receiptUnknown);
    final order = _orders.orders.firstWhere((o) => o.id == receipt.orderId);
    final running = <int, ExactQuantity>{};
    final planned = <ReceiptAllocation>[];
    for (var i = 0; i < allocations.length; i++) {
      planned.add(await _plan(receipt, order, running, i, allocations[i]));
    }
    await _checkPieces(planned, allocations);
    // booked on the ledger the Stock screen reads: one movement per part, from the supplier
    final written = <ReceiptAllocation>[];
    for (var i = 0; i < planned.length; i++) {
      final row = planned[i];
      final part = allocations[i];
      final item = _ledger.itemOf(row.itemId)!;
      final moved = await _ledger.post(
        DemoStockPost(
          item: item,
          quantity: row.inventoryQuantity,
          from: 'demo-place-supplier',
          to: row.locationId,
          reason: 'receipt',
          lotId: (part.lotCode ?? '').isEmpty ? null : row.lotId,
          lotCode: (part.lotCode ?? '').isEmpty ? null : part.lotCode,
          variantId: row.variantId,
          entered: row.enteredQuantity,
          enteredUnit: row.enteredUnit,
        ),
      );
      if (part.tags.isNotEmpty) tags?.addPieces(row.itemId, part.tags, allocation: i);
      written.add(
        ReceiptAllocation(
          id: row.id,
          receiptLineId: row.receiptLineId,
          itemId: row.itemId,
          variantId: row.variantId,
          lotId: row.lotId,
          locationId: row.locationId,
          movementId: moved.id,
          enteredQuantity: row.enteredQuantity,
          inventoryQuantity: row.inventoryQuantity,
          lineNo: row.lineNo,
          enteredUnit: row.enteredUnit,
          orderReference: row.orderReference,
          supplierName: row.supplierName,
          lineText: row.lineText,
        ),
      );
    }
    for (final row in written) {
      _rows.add((row: row, receiptId: receiptId));
    }
    return written;
  }

  /// One part, refused as the server refuses it, or the allocation it makes.
  /// As 0889: an item tagged piece by piece needs one tag per piece of what is put away (DKG25), each tag new
  /// (DKG22, naming the allocation and the tag); tags on any other item are refused (units_not_tracked).
  Future<void> _checkPieces(List<ReceiptAllocation> planned, List<PutAwayAllocation> allocations) async {
    for (var i = 0; i < planned.length; i++) {
      final read = allocations[i].tags;
      final store = tags;
      final mode = await store?.tagModeOf?.call(planned[i].itemId);
      if (store == null || mode != 'per_unit') {
        if (read.isNotEmpty) throw _refused('units', StockRefusal.unitsNotTracked);
        continue;
      }
      if (planned[i].inventoryQuantity != ExactQuantity.parse('${read.length}')) {
        throw StockTagRefused(DkCode.dkg25, {'allocation': i});
      }
      store.addPieces(planned[i].itemId, read, allocation: i, check: true);
    }
  }

  Future<ReceiptAllocation> _plan(
    PurchaseOrderReceipt receipt,
    PurchaseOrder order,
    Map<int, ExactQuantity> running,
    int i,
    PutAwayAllocation a,
  ) async {
    final line = order.lines.where((l) => l.lineNo == a.lineNo).firstOrNull;
    final received = receipt.lines[a.lineNo];
    if (line == null || received == null) throw _refused('allocations[$i].line', StockRefusal.lineUnknown);
    final item = line.serviceId == null ? null : await _config.item(workspaceId, line.serviceId!);
    final unit = line.unit.isEmpty ? item?.inventoryUnit ?? '' : line.unit;
    final already = _rows
            .where((r) => r.row.receiptLineId == '${receipt.id}:${a.lineNo}')
            .fold(ExactQuantity.zero, (s, r) => s + r.row.enteredQuantity) +
        (running[a.lineNo] ?? ExactQuantity.zero);
    final variants = item != null && (await _config.variants(workspaceId, item.itemId)).any((v) => v.active);
    final (entered: qty, :inventory) = _ledger.core.putAwayPart(
      i,
      item: item,
      unit: unit,
      part: a,
      left: exactOfReceived(received) - already,
      hasVariants: variants,
    );
    running[a.lineNo] = (running[a.lineNo] ?? ExactQuantity.zero) + qty;
    final n = _next++;
    return ReceiptAllocation(
      id: 'demo-alloc-$n',
      receiptLineId: '${receipt.id}:${a.lineNo}',
      itemId: item!.itemId,
      variantId: a.variantId,
      lotId: 'demo-lot-$n',
      locationId: a.locationId,
      movementId: 'demo-movement-$n',
      enteredQuantity: qty,
      inventoryQuantity: inventory,
      lineNo: a.lineNo,
      enteredUnit: unit,
      orderReference: order.reference,
      supplierName: order.supplierName,
      lineText: line.description,
    );
  }
}
