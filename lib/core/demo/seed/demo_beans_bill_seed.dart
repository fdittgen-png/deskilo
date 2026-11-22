// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4173 -- the Demo's supplier bill for the coffee beans of the order whose delivery is put away
// into stock, linked to that order the way a bill is (the Demo's order records hold the link), and
// part-paid by a transfer recorded against its payable. It is what the stock's trace follows from a
// delivery to its bill and its payment, and from the bill back to the goods; nothing here is a
// provider's acceptance or a bank reconciliation.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../features/money/domain/purchase.dart';
import '../data/purchase_order_repository.dart';
import '../data/purchase_repository.dart';

const _demoBeansBillId = 'demo-bill-beans';

/// Seeds the beans bill and links it to the beans order; nothing when there is no such order.
void seedDemoBeansBill(FakePurchaseRepository purchases, FakePurchaseOrderRepository orders, DateTime now) {
  final order = orders.orders.where((o) => o.lines.any((l) => l.serviceId == 'demo-item-beans')).firstOrNull;
  if (order == null) return;
  final supplier = orders.suppliers().where((s) => s.id == order.supplierId).firstOrNull;
  const gross = 3600;
  final vat = vatSplit(gross, 20);
  final received = now.subtract(const Duration(days: 8));
  purchases.addApprovedBill(
    PurchaseDetail(
      summary: PurchaseSummary(
        id: _demoBeansBillId,
        kind: PurchaseKind.bill,
        state: PurchaseState.approved,
        category: 'Coffee beans',
        reference: 'CI-${now.year}-0412',
        currency: orders.currency,
        grossCents: gross,
        receivedOn: received,
        supplierId: order.supplierId,
      ),
      revision: 1,
      lines: [
        PurchaseLine(
          lineNo: 1,
          description: 'Coffee beans',
          grossCents: gross,
          netCents: vat.netCents,
          taxCents: vat.vatCents,
          taxRatePercent: 20,
          recoverableTaxCents: vat.vatCents,
          recognitionKind: 'stock',
        ),
      ],
      sources: const [],
      supplierName: supplier?.name ?? order.supplierName,
      dueOn: received.add(const Duration(days: 30)),
    ),
    order.supplierId,
    payments: [
      SettlementAllocation(
        id: 'demo-beans-payment',
        isReversal: false,
        amountCents: 2000,
        method: 'bank_transfer',
        reference: 'Wire CI-${now.year}-0412 (part)',
        paidOn: now.subtract(const Duration(days: 3)),
      ),
    ],
  );
  orders.billOrders[_demoBeansBillId] = order.id;
}
