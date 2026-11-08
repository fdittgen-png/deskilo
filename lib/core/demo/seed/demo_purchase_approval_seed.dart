// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
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
  final foreign = PurchaseSummary(
    id: 'demo-bill-approval-fx',
    kind: PurchaseKind.bill,
    state: PurchaseState.pending,
    category: 'Equipment',
    reference: 'FX-APPROVAL',
    currency: 'CHF',
    grossCents: 12500,
    receivedOn: today,
  );
  purchases
    ..add(PurchaseDetail(
    summary: foreign,
    revision: 1,
    lines: const [PurchaseLine(lineNo: 1, description: 'Equipment', grossCents: 12500)],
    sources: const [],
    supplierName: supplier.name,
    supplierNumber: supplier.number,
  ))
    ..rememberRate(foreign, ExchangeRateEntry(
    rate: ExactDecimal.parse('1.0456789012'),
    rateDate: today,
    source: 'bank',
  ));
}
