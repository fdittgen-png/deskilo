// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'invoice.dart';

/// Localized strings the invoice PDF prints (the BillPdfStrings shape).
class InvoicePdfStrings {
  const InvoicePdfStrings({
    required this.invoiceTitle,
    required this.issuedOn,
    required this.issuedBy,
    required this.billedTo,
    required this.total,
    required this.signature,
  });

  final String invoiceTitle;
  final String issuedOn;
  final String issuedBy;
  final String billedTo;
  final String total;
  final String signature;
}

/// The archive PDF of one invoice (0060): workspace letterhead with its
/// address, the member with theirs, issuer, date, the immutable line
/// items and the digital-signature fingerprint. Everything comes from
/// the invoice's SNAPSHOT fields — never from live data.
Future<Uint8List> buildInvoicePdf({
  required Invoice invoice,
  required InvoicePdfStrings strings,
  required String Function(int cents) money,
  required String dateLabel,
  required pw.Font baseFont,
  required pw.Font boldFont,
}) async {
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
  // Composed off the localized strings, outside the widget calls
  // (HARD RULE #1 lints inline literals).
  final numberLine = '${strings.invoiceTitle} ${invoice.number}';
  final issuedOnLine = '${strings.issuedOn} $dateLabel';
  final issuedByLine = '${strings.issuedBy} ${invoice.issuerName}';
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Letterhead: the workspace and its address.
          pw.Text(invoice.workspaceName,
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (invoice.workspaceAddress.isNotEmpty)
            pw.Text(invoice.workspaceAddress,
                style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 18),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(strings.billedTo,
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                  pw.Text(invoice.memberName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  if (invoice.memberAddress.isNotEmpty)
                    pw.Text(invoice.memberAddress,
                        style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(numberLine,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(issuedOnLine,
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(issuedByLine,
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(invoice.title,
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: const pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(color: PdfColors.grey400, width: 0.4),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              for (final line in invoice.lines)
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Text(line.label,
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Text(money(line.amountCents),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                ]),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Text(strings.total,
                      style:
                          pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Text(money(invoice.totalCents),
                      textAlign: pw.TextAlign.right,
                      style:
                          pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
              ]),
            ],
          ),
          pw.Spacer(),
          // The digital signature: the server-stored SHA-256 fingerprint
          // over the canonical content — reprinting or re-downloading an
          // archive copy always carries the same value.
          pw.Text(strings.signature,
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey700)),
          pw.Text(invoice.signature,
              style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    ),
  );
  return doc.save();
}
