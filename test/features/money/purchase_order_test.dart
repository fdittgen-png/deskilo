// SPDX-License-Identifier: AGPL-3.0-or-later
// Invariant: order amounts come from valid line items and an unsafe email or
// incomplete order cannot be submitted; a valid order renders as a PDF.
import 'dart:io';

import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/domain/purchase_order_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

PurchaseOrder order({String email = 'orders@example.test', int quantity = 2}) =>
    PurchaseOrder(
      workspaceId: 'ws',
      supplierId: 'vendor',
      supplierName: 'Demo supplier',
      recipientEmail: email,
      reference: 'PO-1',
      currency: 'USD',
      issuedAt: DateTime.utc(2026),
      lines: [
        PurchaseOrderLine(
          description: 'Printer paper',
          quantity: quantity,
          unitCents: 350,
        ),
      ],
    );

void main() {
  test('order total is derived and unsafe email is refused', () {
    expect(order().totalCents, 700);
    expect(order().emailable, isTrue);
    expect(
      order(email: 'orders@example.test\nBcc:other@example.test').emailable,
      isFalse,
    );
    expect(order(quantity: 0).valid, isFalse);
    expect(order(email: '').valid, isTrue);
    expect(order(email: '').emailable, isFalse);
  });
  test('a valid order produces a PDF and an invalid one is refused', () async {
    final font = await File('assets/fonts/Roboto-Regular.ttf').readAsBytes();
    const labels = PurchaseOrderPdfLabels(
      title: 'Purchase order',
      supplier: 'Supplier',
      description: 'Description',
      quantity: 'Quantity',
      unitPrice: 'Unit price',
      total: 'Total',
    );
    Future<List<int>> render(PurchaseOrder value) => buildPurchaseOrderPdf(
      value,
      labels: labels,
      fontBytes: font,
      money: (cents, currency) => '$currency ${cents / 100}',
    );
    expect(String.fromCharCodes((await render(order())).take(5)), '%PDF-');
    await expectLater(render(order(quantity: 0)), throwsArgumentError);
  });
}
