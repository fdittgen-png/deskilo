// SPDX-License-Identifier: AGPL-3.0-or-later
// A foreign supplier bill retains the entered rate through approval. The
// quoted rate is invented transaction data, not a current market quotation.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/purchase.dart';
import 'demo_commerce_country_seed.dart';
import 'demo_purchase_seed.dart';

void seedCommerceForeignBill(
  DemoPurchasing purchasing, DemoCommerceSpec spec, DateTime now,
) {
  final swiss = spec.country == 'CH';
  final supplier = Supplier(id: '${spec.prefix}-foreign-software', number: '6',
    name: 'Cross-border Software (Demo)', countryCode: swiss ? 'IT' : 'CH',
    contact: 'billing@software.example.test');
  purchasing.suppliers.suppliers.add(supplier);
  final received = now.subtract(const Duration(days: 3));
  final summary = PurchaseSummary(id: '${spec.prefix}-bill-foreign',
    supplierId: supplier.id, kind: PurchaseKind.bill, state: PurchaseState.draft,
    category: 'Software service', reference: '${spec.prefix.toUpperCase()}-FX-001',
    currency: swiss ? 'EUR' : 'CHF', grossCents: 48000,
    receivedOn: received, originalDate: received);
  purchasing.purchases
    ..rememberRate(summary, ExchangeRateEntry(
      rate: ExactDecimal.parse(swiss ? '0.96' : '1.04'), rateDate: received,
      source: 'bank'))
    ..addPendingBill(PurchaseDetail(summary: summary, revision: 1,
      supplierName: supplier.name, supplierNumber: supplier.number,
      dueOn: received.add(const Duration(days: 30)), sources: const [],
      lines: const [PurchaseLine(lineNo: 1, description: 'Annual software licence',
        grossCents: 48000, netCents: 48000, taxCents: 0, taxRatePercent: 0,
        recognitionKind: 'operating')],
    ));
}
