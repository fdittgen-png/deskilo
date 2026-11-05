// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — each purchasing space's orders to its suppliers: one received
// last month in two deliveries, one partly received, one sent and awaited,
// one draft being prepared, and one cancelled, so the list, the print, the
// edit, a delivery and the cancellation can all be tried. Sending stays in
// the Demo: nothing is e-mailed.
import '../../../features/money/domain/purchase_order.dart';
import '../../../features/money/domain/purchase_order_receipt.dart';
import '../data/purchase_order_repository.dart';

void seedDemoPurchaseOrders(FakePurchaseOrderRepository orders, DateTime now) {
  final suppliers = [
    for (final s in orders.suppliers())
      if (s.isActive) s,
  ];
  if (suppliers.isEmpty) return;
  // The space e-mails its orders from its own address; the Demo keeps no
  // key and sends nothing.
  orders.mail = const PurchaseOrderMailSettings(
    senderEmail: 'orders@space.example',
    senderName: 'Demo space',
    hasApiKey: true,
    revision: 1,
  );
  final items = orders.services();
  String? item(int i) => items.isEmpty ? null : items[i % items.length].id;
  String name(int i) => items.isEmpty ? '' : items[i % items.length].name;
  PurchaseOrder order(
    int n,
    PurchaseOrderState state,
    DateTime created, {
    required int supplier,
    DateTime? expected,
    DateTime? sent,
    Map<int, double> received = const {},
  }) {
    final s = suppliers[supplier % suppliers.length];
    return PurchaseOrder(
      id: 'demo-order-${created.year}-$n',
      reference: '${created.year}-${n.toString().padLeft(4, '0')}',
      supplierId: s.id,
      supplierName: s.name,
      state: state,
      currency: orders.currency,
      revision: 1,
      createdAt: created,
      expectedOn: expected,
      sentAt: sent,
      sentVia: sent == null ? null : 'print',
      cancelledAt: state == PurchaseOrderState.cancelled ? created : null,
      cancelReason: state == PurchaseOrderState.cancelled
          ? 'Ordered twice'
          : '',
      recipientEmail: 'orders@supplier.example',
      lines: [
        PurchaseOrderLine(
          lineNo: 1,
          serviceId: item(n),
          description: name(n).isEmpty ? 'Coffee beans' : name(n),
          quantity: 40,
          unit: 'unit',
          unitPriceCents: 90,
          vatRatePercent: 20,
          receivedQuantity: received[1] ?? 0,
        ),
        PurchaseOrderLine(
          lineNo: 2,
          description: 'Paper towels',
          quantity: 12,
          unit: 'roll',
          unitPriceCents: 150,
          vatRatePercent: 20,
          receivedQuantity: received[2] ?? 0,
        ),
      ],
    );
  }

  final lastMonth = DateTime(now.year, now.month - 1, 5);
  final thisMonth = DateTime(now.year, now.month);
  orders.orders.addAll([
    order(
      1,
      PurchaseOrderState.received,
      lastMonth,
      supplier: 0,
      expected: lastMonth.add(const Duration(days: 7)),
      sent: lastMonth,
      received: {1: 40, 2: 12},
    ),
    order(
      2,
      PurchaseOrderState.cancelled,
      lastMonth.add(const Duration(days: 2)),
      supplier: 1,
    ),
    order(
      3,
      PurchaseOrderState.sent,
      thisMonth,
      supplier: 1,
      expected: thisMonth.add(const Duration(days: 10)),
      sent: thisMonth,
    ),
    order(
      4,
      PurchaseOrderState.draft,
      thisMonth,
      supplier: 0,
      expected: thisMonth.add(const Duration(days: 14)),
    ),
    order(
      5,
      PurchaseOrderState.partlyReceived,
      lastMonth.add(const Duration(days: 15)),
      supplier: 0,
      expected: lastMonth.add(const Duration(days: 20)),
      sent: lastMonth.add(const Duration(days: 15)),
      received: {1: 20},
    ),
  ]);
  // What arrived: the first order in two deliveries, the fifth in one.
  PurchaseOrderReceipt receipt(
    int n,
    int order,
    int days,
    Map<int, double> lines,
  ) => PurchaseOrderReceipt(
    id: 'demo-receipt-$n',
    orderId: 'demo-order-${lastMonth.year}-$order',
    receivedOn: lastMonth.add(Duration(days: days)),
    lines: lines,
    note: n == 1 ? 'Towels short by six' : '',
  );
  orders.receipts.addAll([
    receipt(1, 1, 6, {1: 40, 2: 6}),
    receipt(2, 1, 9, {2: 6}),
    receipt(3, 5, 22, {1: 20}),
  ]);
}
