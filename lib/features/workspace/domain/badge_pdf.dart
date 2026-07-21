// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Printable badge card (0043 UX pass): the one-time badge QR as an A6
/// landscape PDF the owner can download and print — the QR dialog is the
/// only moment the raw token exists, so this is the moment to keep it.
///
/// l10n-free like the bill PDF (ADR 0007): the call site resolves the
/// strings. [baseFont]/[boldFont] must be real TTFs so accented member
/// names encode.
Future<Uint8List> buildBadgePdf({
  required String workspaceName,
  required String memberName,
  required String token,
  required String hint,
  required pw.Font baseFont,
  required pw.Font boldFont,
}) async {
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
  );
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a6.landscape,
      build: (context) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
          // pdf-side radius (the AppRadius lint guards Flutter widgets).
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        padding: const pw.EdgeInsets.all(12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: token,
              width: 110,
              height: 110,
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    memberName,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    workspaceName,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    hint,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return document.save();
}
