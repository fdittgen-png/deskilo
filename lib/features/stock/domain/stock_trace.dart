// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4173 (G6, client) -- goods traced to their documents and payments, and the operational value. The
// server (0865) follows only RECORDED relations and reads each layer under its own right: a layer the
// reader may not see is `unavailable` (never "unpaid", never zero), a relation that is not recorded is
// `not linked` (never "no goods"), and every list says when it was cut short. Nothing here is a
// financial claim: the value is a qualified calculation, not a posted stock-book balance.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// How far a layer of the trace could be read.
enum TraceState {
  /// Recorded and shown.
  linked,

  /// Nothing is recorded: not refused, not unavailable.
  notLinked,

  /// The reader may not see this layer (or its feature is off): it says nothing about existence.
  unavailable,

  /// A list of recorded items.
  listed,

  /// A state a newer server sent and this app does not know: it says nothing, neither linked nor not.
  unknown;

  /// An absent state is nothing recorded, as the server answers a layer it has no row for.
  static TraceState of(String? wire) => switch (wire) {
    'linked' => linked,
    'listed' => listed,
    'unavailable' => unavailable,
    'not_linked' || null => notLinked,
    _ => unknown,
  };
}

/// One allocation or reversal of a supplier payment on an obligation.
class TraceAllocation {
  const TraceAllocation({
    required this.id,
    required this.reversal,
    required this.amountCents,
    required this.paymentId,
    required this.paymentState,
    required this.method,
    required this.currency,
    this.reportedPaidOn,
  });

  final String id;
  final bool reversal;
  final int amountCents;
  final String paymentId;
  final String paymentState;
  final String method;
  final String currency;
  final String? reportedPaidOn;

  factory TraceAllocation.fromJson(JsonReader r) => TraceAllocation(
    id: r.string('allocation_id'),
    reversal: r.string('kind') == 'reversal',
    amountCents: r.integer('amount_cents'),
    paymentId: r.string('payment_id'),
    paymentState: r.stringOr('payment_state'),
    method: r.stringOr('method'),
    currency: r.stringOr('currency'),
    reportedPaidOn: r.stringOrNull('reported_paid_on'),
  );
}

/// What a bill owes to its creditor, and how it was settled where the reader may see payments.
class TraceObligation {
  const TraceObligation({
    required this.id,
    required this.state,
    required this.amountCents,
    required this.currency,
    required this.settlement,
    required this.settlementState,
    required this.settlementTruncated,
    this.dueOn,
  });

  final String id;
  final String state;
  final int amountCents;
  final String currency;
  final String? dueOn;

  /// `listed`, or `unavailable` when the reader may not see payments (NOT unpaid).
  final TraceState settlementState;
  final List<TraceAllocation> settlement;
  final bool settlementTruncated;

  factory TraceObligation.fromJson(JsonReader r) {
    final s = r.objectOrEmpty('settlement');
    final reader = JsonReader.of({'items': s['items']}, context: 'stock_goods_trace_v1');
    return TraceObligation(
      id: r.string('obligation_id'),
      state: r.stringOr('state'),
      amountCents: r.integer('amount_cents'),
      currency: r.stringOr('currency'),
      dueOn: r.stringOrNull('due_on'),
      settlementState: TraceState.of(s['state'] as String?),
      settlement: reader.objects('items', TraceAllocation.fromJson),
      settlementTruncated: s['truncated'] == true,
    );
  }
}

/// A supplier bill linked to the order the goods arrived on.
class TraceBill {
  const TraceBill({
    required this.id,
    required this.kind,
    required this.state,
    required this.reference,
    required this.currency,
    required this.obligations,
    required this.obligationsTruncated,
    this.originalDate,
    this.dueOn,
  });

  final String id;
  final String kind;
  final String state;
  final String reference;
  final String currency;
  final String? originalDate;
  final String? dueOn;
  final List<TraceObligation> obligations;
  final bool obligationsTruncated;

  factory TraceBill.fromJson(JsonReader r) => TraceBill(
    id: r.string('bill_id'),
    kind: r.stringOr('kind'),
    state: r.stringOr('state'),
    reference: r.stringOr('original_reference'),
    currency: r.stringOr('currency'),
    originalDate: r.stringOrNull('original_date'),
    dueOn: r.stringOrNull('due_on'),
    obligations: r.objects('obligations', TraceObligation.fromJson),
    obligationsTruncated: r.isTrue('obligations_truncated'),
  );
}

/// The purchase side of a movement.
class TracePurchase {
  const TracePurchase({
    required this.state,
    required this.billsState,
    required this.bills,
    required this.billsTruncated,
    this.receiptId,
    this.receivedOn,
    this.orderId,
    this.orderReference,
    this.orderState,
    this.supplierName,
  });

  /// `linked`, `notLinked` or `unavailable` (the reader may not see the purchase side).
  final TraceState state;
  final String? receiptId;
  final String? receivedOn;
  final String? orderId;
  final String? orderReference;
  final String? orderState;
  final String? supplierName;

  /// `listed`, `notLinked` (no bill recorded for the order) or `unavailable`.
  final TraceState billsState;
  final List<TraceBill> bills;
  final bool billsTruncated;

  factory TracePurchase.fromJson(JsonReader r) {
    final state = TraceState.of(r.stringOrNull('state'));
    final order = r.objectOrNull('order');
    final receipt = r.objectOrNull('receipt');
    final bills = r.objectOrEmpty('bills');
    return TracePurchase(
      state: state,
      receiptId: receipt?.stringOrNull('receipt_id'),
      receivedOn: receipt?.stringOrNull('received_on'),
      orderId: order?.stringOrNull('order_id'),
      orderReference: order?.stringOrNull('reference'),
      orderState: order?.stringOrNull('state'),
      supplierName: order?.stringOrNull('supplier_name'),
      billsState: TraceState.of(bills['state'] as String?),
      bills: JsonReader.of({'items': bills['items']}, context: 'stock_goods_trace_v1').objects('items', TraceBill.fromJson),
      billsTruncated: bills['truncated'] == true,
    );
  }
}

/// What the goods of a lot cost, as the reader may see it.
class TraceCost {
  const TraceCost({required this.state, this.totalCostMinor, this.sourceCurrency, this.sourceRate});

  /// `known`, `unknown` (nothing was asserted: never zero) or `unavailable` (the reader may not see cost).
  final String state;
  final int? totalCostMinor;
  final String? sourceCurrency;
  final String? sourceRate;

  factory TraceCost.fromJson(JsonReader r) => TraceCost(
    state: r.stringOr('state', 'unavailable'),
    totalCostMinor: r.intOrNull('total_cost_minor'),
    sourceCurrency: r.stringOrNull('source_currency'),
    sourceRate: r.stringOrNull('source_rate'),
  );
}

/// One movement with its lot's cost and what is recorded about its purchase.
class StockTrace {
  const StockTrace({
    required this.movementId,
    required this.quantity,
    required this.reason,
    required this.cost,
    required this.purchase,
    this.lotId,
    this.lotCode,
  });

  final String movementId;
  final ExactQuantity quantity;
  final String reason;
  final String? lotId;
  final String? lotCode;
  final TraceCost? cost;
  final TracePurchase purchase;

  factory StockTrace.fromJson(JsonReader r) {
    final movement = r.objectOrEmpty('movement');
    final m = JsonReader.of(movement, context: 'stock_goods_trace_v1');
    final lot = r.objectOrNull('lot');
    return StockTrace(
      movementId: m.string('movement_id'),
      quantity: ExactQuantity.parse(m.string('quantity')),
      reason: m.stringOr('reason'),
      lotId: lot?.stringOrNull('lot_id'),
      lotCode: lot?.stringOrNull('lot_code'),
      cost: lot?.objectOrNull('cost') == null ? null : TraceCost.fromJson(lot!.objectOrNull('cost')!),
      purchase: TracePurchase.fromJson(JsonReader.of(r.objectOrEmpty('purchase'), context: 'stock_goods_trace_v1')),
    );
  }
}

/// The answer of `stock_goods_trace_v1`: the traces asked for and whether more would follow.
class StockTraceAnswer {
  const StockTraceAnswer({required this.traces, required this.truncated});

  final List<StockTrace> traces;
  final bool truncated;

  factory StockTraceAnswer.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_goods_trace_v1');
    return StockTraceAnswer(
      traces: r.objects('traces', StockTrace.fromJson),
      truncated: r.isTrue('truncated'),
    );
  }
}

/// One priced line of the operational value.
class ValuationLine {
  const ValuationLine({
    required this.itemId,
    required this.quantity,
    required this.valueMinor,
    this.variantId,
    this.lotId,
    this.sourceCurrency,
    this.sourceRate,
  });

  final String itemId;
  final String? variantId;
  final String? lotId;
  final ExactQuantity quantity;

  /// Minor units of the business's currency, an exact integer.
  final int valueMinor;
  final String? sourceCurrency;
  final String? sourceRate;

  factory ValuationLine.fromJson(JsonReader r) => ValuationLine(
    itemId: r.string('item_id'),
    variantId: r.stringOrNull('variant_id'),
    lotId: r.stringOrNull('lot_id'),
    quantity: ExactQuantity.parse(r.string('quantity')),
    valueMinor: r.integer('value_minor'),
    sourceCurrency: r.stringOrNull('source_currency'),
    sourceRate: r.stringOrNull('source_rate'),
  );
}

/// Goods on hand whose cost is unknown: outside the total, by quantity.
class UncostedGroup {
  const UncostedGroup({required this.itemId, required this.quantity, required this.noLot, this.variantId});

  final String itemId;
  final String? variantId;
  final ExactQuantity quantity;

  /// True when the goods have no lot at all; false when their lot has no cost.
  final bool noLot;

  factory UncostedGroup.fromJson(JsonReader r) => UncostedGroup(
    itemId: r.string('item_id'),
    variantId: r.stringOrNull('variant_id'),
    quantity: ExactQuantity.parse(r.string('quantity')),
    noLot: r.string('reason') == 'no_lot',
  );
}

/// The operational value on hand at a cutoff: a qualified calculation, never a posted balance.
class StockValuation {
  const StockValuation({
    required this.cutoff,
    required this.calculatedAt,
    required this.currency,
    required this.movementsCounted,
    required this.knownTotalMinor,
    required this.lines,
    required this.linesTruncated,
    required this.uncosted,
    required this.uncostedTruncated,
    required this.complete,
    this.lastRecordedAt,
  });

  final DateTime cutoff;
  final DateTime calculatedAt;
  final String currency;
  final int movementsCounted;
  final DateTime? lastRecordedAt;

  /// The known costs only, in minor units; complete when [complete].
  final int knownTotalMinor;
  final List<ValuationLine> lines;
  final bool linesTruncated;
  final List<UncostedGroup> uncosted;
  final bool uncostedTruncated;
  final bool complete;

  factory StockValuation.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_valuation_v1');
    return StockValuation(
      cutoff: r.dateTime('cutoff'),
      calculatedAt: r.dateTime('calculated_at'),
      currency: r.stringOr('currency'),
      movementsCounted: r.integer('movements_counted'),
      lastRecordedAt: r.dateTimeOrNull('last_recorded_at'),
      knownTotalMinor: r.numeric('known_total_minor').toInt(),
      lines: r.objects('lines', ValuationLine.fromJson),
      linesTruncated: r.isTrue('lines_truncated'),
      uncosted: r.objects('uncosted', UncostedGroup.fromJson),
      uncostedTruncated: r.isTrue('uncosted_truncated'),
      complete: r.isTrue('complete'),
    );
  }
}

/// One movement that put goods away against a document.
class DocumentGoodsRow {
  const DocumentGoodsRow({
    required this.movementId,
    required this.itemId,
    required this.quantity,
    required this.enteredQuantity,
    required this.enteredUnit,
    required this.occurredAt,
    this.variantId,
  });

  final String movementId;
  final String itemId;
  final String? variantId;

  /// In the item's inventory unit.
  final ExactQuantity quantity;
  final ExactQuantity enteredQuantity;
  final String enteredUnit;
  final DateTime occurredAt;

  factory DocumentGoodsRow.fromJson(JsonReader r) => DocumentGoodsRow(
    movementId: r.string('movement_id'),
    itemId: r.string('item_id'),
    variantId: r.stringOrNull('variant_id'),
    quantity: ExactQuantity.parse(r.string('quantity')),
    enteredQuantity: ExactQuantity.parse(r.string('entered_quantity')),
    enteredUnit: r.stringOr('entered_unit'),
    occurredAt: r.dateTime('occurred_at'),
  );
}

/// A page of the goods put away against a document, a keyset page at a time.
class DocumentGoods {
  const DocumentGoods({required this.state, required this.rows, required this.more, this.next});

  /// `listed`, `notLinked` (no recorded link reaches goods) or `unavailable`.
  final TraceState state;
  final List<DocumentGoodsRow> rows;
  final bool more;

  /// The cursor to send back unchanged for the next page.
  final Map<String, Object?>? next;

  factory DocumentGoods.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_document_goods_v1');
    return DocumentGoods(
      state: TraceState.of(r.stringOrNull('state')),
      rows: r.objects('goods', DocumentGoodsRow.fromJson),
      more: r.isTrue('more'),
      next: r.objectOrNull('next')?.json,
    );
  }
}

/// The reads of #4173 (migration 0865), behind one port so the Demo answers like the server.
abstract interface class StockTraceReader {
  /// The trace of one movement.
  Future<StockTraceAnswer> trace(String workspaceId, String movementId);

  /// The goods put away against a document (`order`, `bill` or `payment`).
  Future<DocumentGoods> documentGoods(
    String workspaceId,
    String kind,
    String id, {
    int limit = 50,
    Map<String, Object?>? after,
  });

  /// The operational value on hand at [at] (now when null); needs the right to see what goods cost.
  Future<StockValuation> valuation(String workspaceId, {DateTime? at});
}
