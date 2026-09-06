// SPDX-License-Identifier: 0BSD
//
// #875 — the block renderer, extracted from invoice_pdf.dart.
//
// The banded engine parses a band into [ReportBlock]s and drew them
// through a private function. The positioned engine's `<markup>`
// element embeds exactly that markup, and must draw it EXACTLY the same
// way, or a design that moves one element at a time into a layout
// would change its look on every step. One renderer, two callers.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import 'invoice_report.dart';
import 'report_style.dart';

List<pw.Widget> reportBlockWidgets(
  List<ReportBlock> blocks, {
  Map<String, Uint8List> images = const {},

  /// #923 — the tallest an unsized image may be here.
  ///
  /// The envelope standard fixes the sender block at 25 mm, and a
  /// letterhead with a logo in it is taller than that: left alone the
  /// band overflowed and was clipped, and the logo — first in the band —
  /// was what disappeared, while the text lines under it survived. So a
  /// caller with a hard band says how tall a picture may be there.
  /// Null anywhere else: outside such a band an image keeps its size.
  double? maxImageHeight,
}) =>
    [
      for (final block in blocks)
        reportBlockWidget(block, images, maxImageHeight: maxImageHeight),
    ];

pw.Widget reportBlockWidget(
  ReportBlock block,
  Map<String, Uint8List> images, {
  double? maxImageHeight,
}) =>
    switch (block) {
      ReportHeading(:final text) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: reportHeadingSize,
                  fontWeight: pw.FontWeight.bold,
                  color: reportInk)),
        ),
      ReportSubheading(:final text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
          child: pw.Text(text.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: reportSubheadingSize,
                  color: reportMuted,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: reportSubheadingTracking)),
        ),
      ReportText(:final text) => pw.Text(text,
          style: const pw.TextStyle(fontSize: reportBodySize, color: reportInk)),
      ReportMuted(:final text) => pw.Text(text,
          style:
              const pw.TextStyle(fontSize: reportSmallSize, color: reportMuted)),
      ReportDivider() => pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 8),
          height: reportRuleThickness,
          color: reportAccent),
      ReportSpacer() => pw.SizedBox(height: reportSpacerSize),
      ReportTableRow(:final cells, :final bold) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cells.length; i++)
                i == 0
                    ? pw.Expanded(
                        child: pw.Text(cells[i],
                            style: pw.TextStyle(
                                fontSize: reportBodySize,
                                color: reportInk,
                                fontWeight: bold
                                    ? pw.FontWeight.bold
                                    : pw.FontWeight.normal)),
                      )
                    : pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 12),
                        child: pw.Text(cells[i],
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: reportBodySize,
                                color: reportInk,
                                fontWeight: bold
                                    ? pw.FontWeight.bold
                                    : pw.FontWeight.normal)),
                      ),
            ],
          ),
        ),
      // #482 — side-by-side columns: equal widths, top-aligned; an
      // empty first column pushes the second to the right.
      ReportColumns(:final columns) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns.length; i++)
              pw.Expanded(
                child: pw.Padding(
                  padding: pw.EdgeInsets.only(left: i == 0 ? 0 : 16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: reportBlockWidgets(columns[i],
                        images: images, maxImageHeight: maxImageHeight),
                  ),
                ),
              ),
          ],
        ),
      // #488 — a library image (the logo…); unresolved → nothing.
      ReportImage(:final name, :final size, :final align) =>
        images[name] == null
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Image(
                  pw.MemoryImage(images[name]!),
                  // #822 — `![name|size|align]`. #923 — a band with a
                  // fixed height CAPS it: the default medium is 64 pt,
                  // which alone overruns the envelope's 25 mm sender
                  // band before a single line of identity is under it.
                  height: maxImageHeight == null
                      ? size.height
                      : math.min(size.height, maxImageHeight),
                  fit: pw.BoxFit.contain,
                  alignment: switch (align) {
                    ReportImageAlign.left => pw.Alignment.centerLeft,
                    ReportImageAlign.center => pw.Alignment.center,
                    ReportImageAlign.right => pw.Alignment.centerRight,
                  },
                ),
              ),
    };
