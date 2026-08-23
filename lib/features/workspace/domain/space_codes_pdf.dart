// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'badge_pdf.dart' show badgeCardWidth, badgeCardHeight;

/// One printable space card: the QR payload plus its labels.
/// [contextLines] are the owner-selected information lines (#584) —
/// workspace/level/room/table/chair, up to the card's own depth.
typedef SpaceCodeEntry = ({
  String name,
  String kindLabel,
  String payload,
  List<String> contextLines,
});

/// The printable card size (#584). All three stay comfortably above the
/// QR module-size floor for phone cameras: even SMALL carries a 26 mm
/// code, ~2× the usual 10–15 cm scan-distance minimum.
enum SpaceCardSize { small, medium, large }

/// The barcode's own size on the card (#596) — independent of the card
/// format, as a share of the card's usable height. MEDIUM reproduces
/// the historical #584 proportions on every card; LARGE stops at 92%
/// so the card padding keeps serving as the QR quiet zone; SMALL still
/// clears the module-size floor on the smallest card (~19 mm edge).
enum SpaceQrSize { small, medium, large }

double _qrShareOf(SpaceQrSize size) => switch (size) {
      SpaceQrSize.small => 0.55,
      SpaceQrSize.medium => 0.78,
      SpaceQrSize.large => 0.92,
    };

/// The QR edge, in PDF points, for a card/code size combination — the
/// chosen share of the card's height inside its padding. Pure so the
/// nine combinations are testable without rendering a document.
double spaceQrEdge(SpaceCardSize card, SpaceQrSize qr) {
  final g = _geometryOf(card);
  return (g.height - 2 * _cardPadding) * _qrShareOf(qr);
}

const double _cardPadding = 8;

/// Which information the owner puts on the cards (#584): printed as
/// context lines AND embedded in the QR's URI, so a generic scanner
/// app shows the names too. Declaration order is the print order.
enum SpaceCardInfo {
  workspace('workspace'),
  level('level'),
  room('room'),
  table('table'),
  chair('chair');

  const SpaceCardInfo(this.wire);

  /// The QR query-parameter name carrying this info.
  final String wire;
}

/// Per-size geometry: card box, grid, and type sizes. The medium card
/// is the proven badge-sheet credit card (2×5 per A4).
({
  double width,
  double height,
  int columns,
  int rows,
  double nameSize,
  double lineSize,
}) _geometryOf(SpaceCardSize size) => switch (size) {
      SpaceCardSize.small => (
          width: 60 * PdfPageFormat.mm,
          height: 40 * PdfPageFormat.mm,
          columns: 3,
          rows: 6,
          nameSize: 9,
          lineSize: 6.5,
        ),
      SpaceCardSize.medium => (
          width: badgeCardWidth,
          height: badgeCardHeight,
          columns: 2,
          rows: 5,
          nameSize: 12,
          lineSize: 8,
        ),
      SpaceCardSize.large => (
          width: 186 * PdfPageFormat.mm,
          height: 84 * PdfPageFormat.mm,
          columns: 1,
          rows: 3,
          nameSize: 18,
          lineSize: 11,
        ),
    };

/// The space QR sheet (field request, sizes + info #584): one QR card
/// per desk, office, level and chair, on A4 pages — print, cut, stick
/// each card on its space. Scanning it in the app opens that space's
/// permitted actions.
Future<Uint8List> buildSpaceCodesPdf({
  required String workspaceName,
  required List<SpaceCodeEntry> entries,
  required pw.Font baseFont,
  required pw.Font boldFont,
  SpaceCardSize size = SpaceCardSize.medium,
  SpaceQrSize qrSize = SpaceQrSize.medium,
}) async {
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
  final g = _geometryOf(size);
  final qrEdge = spaceQrEdge(size, qrSize);
  final perPage = g.columns * g.rows;

  pw.Widget card(SpaceCodeEntry entry) => pw.Container(
        width: g.width,
        height: g.height,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        padding: const pw.EdgeInsets.all(_cardPadding),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: entry.payload,
              width: qrEdge,
              height: qrEdge,
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
                      fontSize: g.nameSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    entry.kindLabel,
                    maxLines: 1,
                    style: pw.TextStyle(
                      fontSize: g.lineSize,
                      color: PdfColors.grey700,
                    ),
                  ),
                  for (final line in entry.contextLines) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      line,
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      style: pw.TextStyle(
                        fontSize: g.lineSize,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  for (var start = 0; start < entries.length; start += perPage) {
    final page = entries.sublist(
      start,
      start + perPage > entries.length ? entries.length : start + perPage,
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        theme: theme,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var row = 0; row < g.rows; row++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1),
                child: pw.Row(
                  children: [
                    for (var col = 0; col < g.columns; col++)
                      if (row * g.columns + col < page.length)
                        pw.Padding(
                          padding:
                              const pw.EdgeInsets.symmetric(horizontal: 1.5),
                          child: card(page[row * g.columns + col]),
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
