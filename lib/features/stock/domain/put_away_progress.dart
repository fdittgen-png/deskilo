// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4171 (B) -- what a delivery brought, what of it was put away into stock,
// and what is still to put away, line by line. Pure Dart: the order pane
// shows it and the put-away form takes its defaults from it. Quantities are
// in the unit of the order line, as the delivery counted them.
library;

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity;

import '../../money/domain/purchase_order.dart';
import '../../money/domain/purchase_order_receipt.dart';
import 'stock_receiving.dart';

/// One delivered line with what was put away of it.
class DeliveredLineProgress {
  const DeliveredLineProgress({
    required this.lineNo,
    required this.description,
    required this.unit,
    required this.serviceId,
    required this.received,
    required this.putAway,
  });

  final int lineNo;
  final String description;
  final String unit;
  final String? serviceId;
  final ExactQuantity received;
  final ExactQuantity putAway;

  /// What is still to put away; never below zero nor above what was received.
  ExactQuantity get remaining {
    final left = received - putAway;
    if (left.isNegative) return ExactQuantity.zero;
    return left > received ? received : left;
  }
}

/// #4393 -- a delivered quantity as the purchase order reads it (the order's
/// numbers are its own, #4177) brought into the exact type once, here: a
/// stored `numeric(18,6)` always has an exact six-decimal text, and anything
/// else is refused with a typed [ExactQuantityException], never rounded.
ExactQuantity exactOfReceived(num delivered) => ExactQuantity.parse(
  delivered == delivered.truncate() ? delivered.truncate().toString() : delivered.toString(),
);

/// The lines of [receipt], each with the allocations that name its receipt
/// line (by id, or by the line number when the id was not read).
List<DeliveredLineProgress> progressOfDelivery(
  PurchaseOrder order,
  PurchaseOrderReceipt receipt,
  List<ReceiptAllocation> allocations,
) => [
  for (final line in order.lines)
    if ((receipt.lines[line.lineNo] ?? 0) > 0)
      DeliveredLineProgress(
        lineNo: line.lineNo,
        description: line.description,
        unit: line.unit,
        serviceId: line.serviceId,
        received: exactOfReceived(receipt.lines[line.lineNo]!),
        putAway: allocations
            .where((a) => a.receiptLineId == receipt.lineIds[line.lineNo])
            .fold(ExactQuantity.zero, (sum, a) => sum + a.enteredQuantity),
      ),
];
