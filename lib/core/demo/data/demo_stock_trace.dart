// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4173 -- the Demo's trace of goods and operational value, behind the same port as the server's.
// Nothing is made up: a movement is traced to the order only when a delivery of one of the Demo's
// orders was put away as that movement (the same allocation the receiving commands wrote), the bills
// are the ones linked to that order in the Demo's order records, and no payment exists in the Demo
// so none is shown. The value is what is on hand at the registry's last known cost; the items with no
// cost (the mugs) are listed as unknown and stay out of the total.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_trace.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'demo_stock_ledger.dart';
import 'demo_stock_queries.dart';
import 'demo_stock_receiving_commands.dart';
import 'demo_stock_registry.dart';
import 'purchase_order_repository.dart';
import 'purchase_repository.dart';

/// The in-memory trace of the reference business.
class DemoStockTrace implements StockTraceReader {
  DemoStockTrace(this._workspaceId, this._ledger, this._orders, this._receiving, this._purchases);

  final String _workspaceId;
  final DemoStockLedger _ledger;
  final FakePurchaseOrderRepository _orders;
  final DemoStockReceivingCommands _receiving;
  final FakePurchaseRepository _purchases;

  String get _currency => _orders.currency;

  bool _mine(String id) => id == _workspaceId;

  /// The order (and receipt) whose delivery was put away as [movementId], when one was.
  Future<({String orderId, String receiptId, String reference, String supplier, DateTime receivedOn})?> _orderOf(String movementId) async {
    for (final order in _orders.orders) {
      for (final a in await _receiving.allocationsOfOrder(_workspaceId, order.id)) {
        if (a.movementId != movementId) continue;
        final receipt = _orders.receipts.where((r) => r.orderId == order.id).firstOrNull;
        return (
          orderId: order.id,
          receiptId: receipt?.id ?? '',
          reference: order.reference,
          supplier: order.supplierName,
          receivedOn: receipt?.receivedOn ?? _orders.now(),
        );
      }
    }
    return null;
  }

  /// The bills linked to [orderId] in the Demo's order records, as the purchase records hold them:
  /// each bill's obligation and the payments recorded against it.
  Future<List<TraceBill>> _billsOf(String orderId) async {
    final bills = <TraceBill>[];
    for (final e in _orders.billOrders.entries) {
      if (e.value != orderId) continue;
      final d = await _purchases.fetchDetail(_workspaceId, e.key);
      bills.add(
        TraceBill(
          id: d.summary.id,
          kind: 'bill',
          state: d.summary.state.name,
          reference: d.summary.reference,
          currency: d.summary.currency,
          dueOn: d.dueOn?.toIso8601String().substring(0, 10),
          obligationsTruncated: false,
          obligations: [
            for (final o in d.obligations)
              TraceObligation(
                id: o.id,
                state: o.state.name,
                amountCents: o.amountCents,
                currency: o.currency,
                settlementState: TraceState.listed,
                settlementTruncated: false,
                settlement: [
                  for (final a in o.allocations)
                    TraceAllocation(
                      id: a.id,
                      reversal: a.isReversal,
                      amountCents: a.amountCents,
                      paymentId: a.id,
                      paymentState: 'reported',
                      method: a.method,
                      currency: o.currency,
                      reportedPaidOn: a.paidOn?.toIso8601String().substring(0, 10),
                    ),
                ],
              ),
          ],
        ),
      );
    }
    return bills;
  }

  @override
  Future<StockTraceAnswer> trace(String workspaceId, String movementId) async {
    if (!_mine(workspaceId)) throw const StockConfigRefused('movement', StockRefusal.malformed);
    final m = await DemoStockQueries(_ledger).movement(workspaceId, movementId);
    if (m == null) throw const StockConfigRefused('movement', StockRefusal.malformed);
    final link = await _orderOf(movementId);
    final bills = link == null ? const <TraceBill>[] : await _billsOf(link.orderId);
    return StockTraceAnswer(
      truncated: false,
      traces: [
        StockTrace(
          movementId: m.id,
          quantity: m.quantity,
          reason: m.reason,
          lotId: m.lotId,
          lotCode: m.lotCode,
          cost: const TraceCost(state: 'unknown'),
          purchase: link == null
              ? const TracePurchase(state: TraceState.notLinked, billsState: TraceState.notLinked, bills: [], billsTruncated: false)
              : TracePurchase(
                  state: TraceState.linked,
                  receiptId: link.receiptId,
                  receivedOn: link.receivedOn.toIso8601String().substring(0, 10),
                  orderId: link.orderId,
                  orderReference: link.reference,
                  supplierName: link.supplier,
                  billsState: bills.isEmpty ? TraceState.notLinked : TraceState.listed,
                  bills: bills,
                  billsTruncated: false,
                ),
        ),
      ],
    );
  }

  static int _skip(Map<String, Object?>? after) => (after?['offset'] as int?) ?? 0;

  @override
  Future<DocumentGoods> documentGoods(
    String workspaceId,
    String kind,
    String id, {
    int limit = 50,
    Map<String, Object?>? after,
  }) async {
    if (!_mine(workspaceId)) throw const StockConfigRefused('document', StockRefusal.malformed);
    final orderId = switch (kind) {
      'order' => id,
      'bill' => _orders.billOrders[id],
      _ => null,
    };
    if (orderId == null) return const DocumentGoods(state: TraceState.notLinked, rows: <DocumentGoodsRow>[], more: false);
    final allocations = await _receiving.allocationsOfOrder(workspaceId, orderId);
    final queries = DemoStockQueries(_ledger);
    final rows = <DocumentGoodsRow>[];
    for (final a in allocations.skip(_skip(after)).take(limit)) {
      final m = await queries.movement(workspaceId, a.movementId);
      if (m == null) continue;
      rows.add(
        DocumentGoodsRow(
          movementId: m.id,
          itemId: m.itemId,
          quantity: m.quantity,
          enteredQuantity: m.enteredQuantity,
          enteredUnit: m.enteredUnit,
          occurredAt: m.occurredAt,
        ),
      );
    }
    final consumed = _skip(after) + limit;
    return DocumentGoods(
      state: TraceState.listed,
      rows: rows,
      more: allocations.length > consumed,
      next: allocations.length > consumed ? {'offset': consumed} : null,
    );
  }

  @override
  Future<StockValuation> valuation(String workspaceId, {DateTime? at}) async {
    if (!_mine(workspaceId)) throw const StockConfigRefused('workspace', StockRefusal.malformed);
    final rows = await _ledger.onHand();
    final lines = <ValuationLine>[];
    final unknown = <String, ExactQuantity>{};
    var total = BigInt.zero;
    for (final r in rows) {
      final cost = DemoStockRegistry.catalogue[r.itemId]?.$3;
      if (cost == null) {
        unknown[r.itemId] = (unknown[r.itemId] ?? ExactQuantity.zero) + r.quantity;
        continue;
      }
      // half away from zero, once: quantity (millionths) x unit cost (minor units) / 1e6
      final scaled = r.quantity.micro * BigInt.parse(cost);
      final unit = BigInt.from(10).pow(exactQuantityScale);
      final value = (scaled + unit ~/ BigInt.two) ~/ unit;
      total += value;
      lines.add(ValuationLine(itemId: r.itemId, lotId: r.lotId, quantity: r.quantity, valueMinor: value.toInt()));
    }
    final now = at ?? _orders.now();
    return StockValuation(
      cutoff: now,
      calculatedAt: _orders.now(),
      currency: _currency,
      movementsCounted: rows.length,
      knownTotalMinor: total.toInt(),
      lines: lines,
      linesTruncated: false,
      uncosted: [for (final e in unknown.entries) UncostedGroup(itemId: e.key, quantity: e.value, noLot: false)],
      uncostedTruncated: false,
      complete: unknown.isEmpty,
    );
  }
}
