// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Credit-card badge dimensions (ISO/IEC 7810 ID-1: 85.60 × 53.98 mm).
const double badgeCardWidth = 85.6 * PdfPageFormat.mm;
const double badgeCardHeight = 53.98 * PdfPageFormat.mm;

/// Cards per A4 sheet: 2 columns × 5 rows — the standard badge-sheet
/// layout (fits 2×85.6 mm + gutters across, 5×53.98 mm + gutters down).
const int badgeSheetColumns = 2;
const int badgeSheetRows = 5;
const int badgeSheetCount = badgeSheetColumns * badgeSheetRows;

/// Printable badge sheet (0043 UX pass, A4 revision): the one-time badge
/// QR repeated [badgeSheetCount] times at CREDIT-CARD size on one A4
/// page — print once, cut along the borders, and keep spares. The QR
/// dialog is the only moment the raw token exists, so this is the moment
/// to keep it.
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

  pw.Widget card() => pw.Container(
        width: badgeCardWidth,
        height: badgeCardHeight,
        decoration: pw.BoxDecoration(
          // Hairline border doubles as the cut line.
          border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
          // pdf-side radius (the AppRadius lint guards Flutter widgets).
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: token,
              width: 38 * PdfPageFormat.mm,
              height: 38 * PdfPageFormat.mm,
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    memberName,
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    workspaceName,
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    hint,
                    maxLines: 3,
                    overflow: pw.TextOverflow.clip,
                    style: const pw.TextStyle(
                      fontSize: 6,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      // 10 mm margins: 2×85.6 mm columns and 5×53.98 mm rows only fit
      // inside 190×277 mm — the default 20 mm margins would overflow.
      margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            for (var row = 0; row < badgeSheetRows; row++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    for (var col = 0; col < badgeSheetColumns; col++)
                      pw.Padding(
                        padding:
                            const pw.EdgeInsets.symmetric(horizontal: 1.5),
                        child: card(),
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
