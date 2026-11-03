// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'purchase_order.dart';

/// Labels come from the caller's locale, not the order data.
class PurchaseOrderPdfLabels {
  const PurchaseOrderPdfLabels({
    required this.title,
    required this.supplier,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
  final String title;
  final String supplier;
  final String description;
  final String quantity;
  final String unitPrice;
  final String total;
}

Future<Uint8List> buildPurchaseOrderPdf(
  PurchaseOrder order, {
  required PurchaseOrderPdfLabels labels,
  required Uint8List fontBytes,
  required String Function(int cents, String currency) money,
}) async {
  if (!order.valid) throw ArgumentError('purchase order is incomplete');
  final font = pw.Font.ttf(ByteData.sublistView(fontBytes));
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font),
      build: (context) => [
        pw.Text(labels.title, style: pw.TextStyle(fontSize: 24)),
        pw.SizedBox(height: 8),
        pw.Text(order.reference),
        pw.Text('${labels.supplier}: ${order.supplierName}'),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: [
            labels.description,
            labels.quantity,
            labels.unitPrice,
            labels.total,
          ],
          data: [
            for (final line in order.lines)
              [
                line.description,
                '${line.quantity}',
                money(line.unitCents, order.currency),
                money(line.totalCents, order.currency),
              ],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${labels.total}: ${money(order.totalCents, order.currency)}',
          ),
        ),
      ],
    ),
  );
  return doc.save();
}
