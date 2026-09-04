// SPDX-License-Identifier: 0BSD
//
// #875 — the block renderer, extracted from invoice_pdf.dart.
//
// The banded engine parses a band into [ReportBlock]s and drew them
// through a private function. The positioned engine's `<markup>`
// element embeds exactly that markup, and must draw it EXACTLY the same
// way, or a design that moves one element at a time into a layout
// would change its look on every step. One renderer, two callers.
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import 'invoice_report.dart';
import 'report_style.dart';

List<pw.Widget> reportBlockWidgets(
  List<ReportBlock> blocks, {
  Map<String, Uint8List> images = const {},
}) =>
    [for (final block in blocks) reportBlockWidget(block, images)];

pw.Widget reportBlockWidget(
  ReportBlock block,
  Map<String, Uint8List> images,
) =>
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
                    children: reportBlockWidgets(columns[i], images: images),
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
                  // #822 — `![name|size|align]`.
                  height: size.height,
                  fit: pw.BoxFit.contain,
                  alignment: switch (align) {
                    ReportImageAlign.left => pw.Alignment.centerLeft,
                    ReportImageAlign.center => pw.Alignment.center,
                    ReportImageAlign.right => pw.Alignment.centerRight,
                  },
                ),
              ),
    };
