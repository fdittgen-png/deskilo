// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/supplier.dart';
import '../data/purchase_repository.dart';

/// A bill sent by another Demo member, available for the approval journey.
void seedDemoPurchaseApproval(
  FakePurchaseRepository purchases,
  DateTime today,
  Supplier supplier,
) {
  purchases.add(
    PurchaseDetail(
      summary: PurchaseSummary(
        id: 'demo-bill-approval',
        kind: PurchaseKind.bill,
        state: PurchaseState.pending,
        category: 'Telecom service',
        reference: 'OT-APPROVAL',
        currency: 'EUR',
        grossCents: 5880,
        receivedOn: today,
      ),
      revision: 1,
      lines: const [
        PurchaseLine(
          lineNo: 1,
          description: 'Telecom service',
          grossCents: 5880,
          netCents: 4900,
          taxCents: 980,
          taxRatePercent: 20,
        ),
      ],
      sources: const [],
      supplierName: supplier.name,
      supplierNumber: supplier.number,
    ),
  );
}
