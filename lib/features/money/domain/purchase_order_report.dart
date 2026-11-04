// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — what the purchase order's document prints: the supplier in the
// address window, the order's number, its dates, its lines and totals, in
// the order's currency. Pure: the words and the formats come in.
library;

import 'purchase_order.dart';
import 'supplier.dart';

/// The data of [order] to [supplier] for the `purchase_order` kind, under
/// [letterhead] (the space's name, address and legal mentions).
Map<String, Object?> purchaseOrderReportData(
  PurchaseOrder order, {
  required Supplier? supplier,
  required String Function(int minor) money,
  required String Function(DateTime day) date,
  required String Function(double quantity) quantity,
  required DateTime issued,
  required String issuedBy,
  Map<String, Object?> letterhead = const {},
}) => {
  ...letterhead,
  'number': order.reference,
  'issued': date(order.sentAt ?? issued),
  'issued_by': issuedBy,
  'expected_on': switch (order.expectedOn) {
    final d? => date(d),
    null => '',
  },
  'client_name': supplier?.name ?? order.supplierName,
  'client_address': [
    if (supplier != null) ...[
      supplier.street,
      [supplier.postalCode, supplier.city].where((p) => p.isNotEmpty).join(' '),
      supplier.countryCode,
    ],
  ].where((p) => p.trim().isNotEmpty).join('\n'),
  'lines': [
    for (final l in order.lines)
      {
        'label': l.unit.isEmpty
            ? l.description
            : '${l.description} (${l.unit})',
        'qty': quantity(l.quantity),
        'unit_price': money(l.unitPriceCents),
        'amount': money(l.netCents),
      },
  ],
  'net_total': money(order.netCents),
  'vat_total': money(order.vatCents),
  'has_vat': order.vatCents != 0,
  'total': money(order.totalCents),
  'note': order.note,
};
