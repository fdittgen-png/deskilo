// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'badge_pdf.dart' show badgeCardWidth, badgeCardHeight,
    badgeSheetColumns, badgeSheetRows, badgeSheetCount;

/// One printable space card: the QR payload plus its labels.
typedef SpaceCodeEntry = ({String name, String kindLabel, String payload});

/// The space QR sheet (field request): one credit-card QR per desk,
/// office and level, on A4 pages in the badge-sheet grid — print, cut,
/// stick each card on its space. Scanning it in the app opens that
/// space's permitted actions.
Future<Uint8List> buildSpaceCodesPdf({
  required String workspaceName,
  required List<SpaceCodeEntry> entries,
  required pw.Font baseFont,
  required pw.Font boldFont,
}) async {
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);

  pw.Widget card(SpaceCodeEntry entry) => pw.Container(
        width: badgeCardWidth,
        height: badgeCardHeight,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: entry.payload,
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
                    entry.name,
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    entry.kindLabel,
                    maxLines: 1,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    workspaceName,
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // Chunk into badge-grid pages (2×5 per A4, 10 mm margins — the badge
  // sheet's proven-fit geometry).
  for (var start = 0; start < entries.length; start += badgeSheetCount) {
    final page = entries.sublist(
      start,
      start + badgeSheetCount > entries.length
          ? entries.length
          : start + badgeSheetCount,
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        theme: theme,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var row = 0; row < badgeSheetRows; row++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1),
                child: pw.Row(
                  children: [
                    for (var col = 0; col < badgeSheetColumns; col++)
                      if (row * badgeSheetColumns + col < page.length)
                        pw.Padding(
                          padding:
                              const pw.EdgeInsets.symmetric(horizontal: 1.5),
                          child:
                              card(page[row * badgeSheetColumns + col]),
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  return doc.save();
}
