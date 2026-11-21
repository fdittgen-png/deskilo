// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4171 (B) -- what a delivery brought, what of it was put away into stock,
// and what is still to put away, line by line. Pure Dart: the order pane
// shows it and the put-away form takes its defaults from it. Quantities are
// in the unit of the order line, as the delivery counted them.
library;

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
  final double received;
  final double putAway;

  /// What is still to put away; never below zero.
  double get remaining => (received - putAway).clamp(0, received);
}

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
        received: receipt.lines[line.lineNo]!,
        putAway: allocations
            .where((a) => a.receiptLineId == receipt.lineIds[line.lineNo])
            .fold(0.0, (sum, a) => sum + (double.tryParse(a.enteredQuantity.text) ?? 0)),
      ),
];
