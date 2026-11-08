// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — what arrived of a purchase order: one delivery, on its day, with
// how much of each line it brought. The server records it, keeps every
// line within what was ordered and moves the order to partly received or
// received (`record_purchase_order_receipt_v1`, 0684); this layer reads the
// deliveries and checks one before it is recorded.
//
// Pure Dart: no Flutter, no l10n.
library;

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'purchase_order.dart';

/// One delivery of an order.
class PurchaseOrderReceipt {
  const PurchaseOrderReceipt({
    required this.id,
    required this.orderId,
    required this.receivedOn,
    required this.lines,
    this.note = '',
  });

  factory PurchaseOrderReceipt.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'purchase order receipt');
    return PurchaseOrderReceipt(
      id: r.string('id'),
      orderId: r.string('order_id'),
      receivedOn: r.dateTime('received_on'),
      note: r.stringOr('note'),
      lines: {
        for (final l in r.objects(
          'purchase_order_receipt_lines',
          (l) => (
            no: l.objectOrNull('purchase_order_lines')?.integer('line_no') ?? 0,
            qty: l.doubleOrNull('quantity') ?? 0,
          ),
        ))
          l.no: l.qty,
      },
    );
  }

  final String id;
  final String orderId;
  final DateTime receivedOn;
  final String note;

  /// How much of each order line (by its number) arrived.
  final Map<int, double> lines;
}

/// What a delivery cannot be.
enum PurchaseOrderReceiptProblem {
  /// The order is a draft, received or cancelled.
  notReceivable,

  /// No line brings anything.
  nothing,

  /// A line would receive more than what is left of it.
  tooMany,

  /// The day lies after today.
  future,
}

extension PurchaseOrderReceiving on PurchaseOrder {
  /// A sent or partly received order receives its goods.
  bool get receivable =>
      state == PurchaseOrderState.sent ||
      state == PurchaseOrderState.partlyReceived;
}

extension PurchaseOrderLineRemaining on PurchaseOrderLine {
  /// What is still to arrive of the line.
  double get remaining =>
      quantity - receivedQuantity > 0 ? quantity - receivedQuantity : 0;
}

/// A delivery being entered: its day, a note, and how much of each line
/// (by its number) arrived; an empty or zero quantity brings nothing.
class PurchaseOrderReceiptDraft {
  const PurchaseOrderReceiptDraft({
    required this.order,
    required this.receivedOn,
    required this.quantities,
    this.note = '',
  });

  final PurchaseOrder order;
  final DateTime receivedOn;
  final Map<int, double> quantities;
  final String note;

  Iterable<MapEntry<int, double>> get _brought =>
      quantities.entries.where((e) => e.value > 0);

  /// What keeps the delivery from being recorded on [today], in the order
  /// the form shows them.
  List<PurchaseOrderReceiptProblem> problemsOn(DateTime today) => [
    if (!order.receivable) PurchaseOrderReceiptProblem.notReceivable,
    if (_brought.isEmpty) PurchaseOrderReceiptProblem.nothing,
    if (quantities.values.any((q) => q < 0) ||
        _brought.any(
          (e) => order.lines.any(
            (l) => l.lineNo == e.key && e.value > l.remaining,
          ),
        ))
      PurchaseOrderReceiptProblem.tooMany,
    if (isoDay(receivedOn).compareTo(isoDay(today)) > 0)
      PurchaseOrderReceiptProblem.future,
  ];

  /// The lines the server records: `[{line_no, quantity}]`.
  List<Map<String, Object>> toLines() => [
    for (final e in _brought) {'line_no': e.key, 'quantity': e.value},
  ];
}
