// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4293 -- the labels of the places, to print and stick on the shelf: each one says the place's
// ADDRESS large (MAG1-SALES-A03-B02-S4), its name beneath, and carries a Code 128 barcode of the
// place's own barcode when it has one, else of its address, so a scan finds the place. Pure like the
// other documents (ADR 0007): no l10n, the fonts are handed in (real TTFs, so accents encode).
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One label: what is printed for one place.
class PlaceLabel {
  const PlaceLabel({required this.address, required this.barcode, this.name = ''});

  /// The address as the business writes it (with its separator).
  final String address;

  /// What the barcode carries: the place's own barcode, else its address.
  final String barcode;
  final String name;
}

/// A label's size, in millimetres: two across and seven down an A4 page.
const double _labelWidthMm = 90;
const double _labelHeightMm = 38;

/// The labels of [labels] on A4 pages, two across, as many pages as there are labels.
Future<Uint8List> buildPlaceLabelsPdf({
  required List<PlaceLabel> labels,
  required pw.Font baseFont,
  required pw.Font boldFont,
}) async {
  final document = pw.Document(theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont));
  pw.Widget label(PlaceLabel l) => pw.Container(
    width: _labelWidthMm * PdfPageFormat.mm,
    height: _labelHeightMm * PdfPageFormat.mm,
    decoration: pw.BoxDecoration(
      // a hairline that doubles as the cut line
      border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
    ),
    padding: const pw.EdgeInsets.all(6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          l.address,
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        if (l.name.isNotEmpty)
          pw.Text(l.name, maxLines: 1, overflow: pw.TextOverflow.clip, style: const pw.TextStyle(fontSize: 9)),
        pw.BarcodeWidget(
          barcode: pw.Barcode.code128(),
          data: l.barcode,
          width: 78 * PdfPageFormat.mm,
          height: 11 * PdfPageFormat.mm,
          drawText: false,
        ),
      ],
    ),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
      build: (context) => [
        pw.Wrap(spacing: 4, runSpacing: 4, children: [for (final l in labels) label(l)]),
      ],
    ),
  );
  return document.save();
}
