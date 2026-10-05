// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Business analytics report as a PDF: the dashboard on paper. It
// renders the same [BiDashboardContent] the screen renders — the figure,
// how it moved, the evolution with its projection (dashed, its range
// shaded, labelled an estimate), how now compares with the past, and what
// it is made of — so the report and the screen cannot disagree. A gap in
// the data is a gap in the line; a running period is marked.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'bi_analysis.dart';
import 'bi_report_content.dart';
import '../../money/domain/invoice_pdf.dart' show watermarkForeground;
import '../../money/domain/invoice_report.dart';
import '../../money/domain/report_block_widgets.dart';
import '../../money/domain/report_flow_page.dart';

/// The report: a header, one section per analysis, a closing note.
Future<Uint8List> buildBiReportPdf({
  required String title,
  required String workspaceName,
  required String subtitle,
  required String producedOn,
  required String estimateNote,
  required List<BiDashboardContent> sections,
  required pw.Font baseFont,
  required pw.Font boldFont,
  InvoiceReport? report,
  Map<String, Uint8List> images = const {},
  String pageLabel = 'Page',
  String watermark = '',
}) async {
  final document = pw.Document(title: title);
  final content = report ?? InvoiceReport(
    header: [ReportHeading(title), ReportText(workspaceName),
      ReportMuted('$subtitle · $producedOn')],
    body: const [], footer: const []);
  document.addPage(reportFlowPage(
    pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
        buildForeground: watermarkForeground(watermark)),
    documentTitle: title, pageLabel: pageLabel,
    firstHeader: (context) => reportBlockWidgets(content.header, images: images),
    continuation: content.continuation.isEmpty ? null :
        (context) => reportBlockWidgets(content.continuation, images: images),
    footer: (context) => reportBlockWidgets(content.footer, images: images),
    body: (context) => [
      ...reportBlockWidgets(content.body, images: images),
      ...biReportBodyWidgets(sections, estimateNote),
    ],
  ));
  return document.save();
}

/// Authoritative dashboard figures and charts remain present even when
/// the owner personalizes the report's surrounding text and images.
List<pw.Widget> biReportBodyWidgets(List<BiDashboardContent> sections, String estimateNote) => [
  for (final section in sections) ..._section(section),
  pw.SizedBox(height: 8),
  pw.Text(estimateNote, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
];

const _accent = PdfColors.deepOrange800;
const _projection = PdfColors.teal700;

List<pw.Widget> _section(BiDashboardContent c) => [
  pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
    ),
    child: pw.Text(
      c.title,
      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
    ),
  ),
  pw.SizedBox(height: 6),
  pw.Text(c.period, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
  pw.Text(c.figure, style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
  if (c.basis.isNotEmpty) pw.Text(c.basis, style: const pw.TextStyle(fontSize: 9)),
  pw.SizedBox(height: 4),
  if (c.chips.isEmpty)
    pw.Text(c.noComparisonLabel, style: const pw.TextStyle(fontSize: 9))
  else
    pw.Wrap(
      spacing: 10,
      children: [
        for (final chip in c.chips)
          pw.Text(
            chip.label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
      ],
    ),
  if (c.narrative != null) pw.Text(c.narrative!, style: const pw.TextStyle(fontSize: 10)),
  if (c.provisionalNote != null)
    pw.Text(
      c.provisionalNote!,
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
    ),
  if (c.runRate != null) pw.Text(c.runRate!, style: const pw.TextStyle(fontSize: 10)),
  pw.SizedBox(height: 8),
  pw.Text(c.evolutionTitle, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
  pw.SizedBox(height: 4),
  _evolution(c),
  pw.SizedBox(height: 3),
  pw.Text(c.projectionBasis, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
  if (c.projectionNext != null)
    pw.Text(c.projectionNext!, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
  pw.SizedBox(height: 8),
  pw.Text(c.compareTitle, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
  pw.SizedBox(height: 4),
  ..._bars(c),
  for (final comp in c.compositions) ..._composition(comp),
  for (final note in c.notes)
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Text(note, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ),
  pw.SizedBox(height: 18),
];

pw.Widget _evolution(BiDashboardContent c) {
  final points = c.series.points;
  final fc = c.forecast?.points ?? const <BiForecastPoint>[];
  final values = <double>[
    for (final p in points)
      if (p.value != null) p.value!.toDouble(),
    for (final f in fc) ...[f.low, f.high],
  ];
  if (values.isEmpty) {
    return pw.Text(c.noDataLabel, style: const pw.TextStyle(fontSize: 9));
  }
  final lo = math.min(0.0, values.reduce(math.min));
  var hi = values.reduce(math.max);
  if (hi <= lo) hi = lo + 1;
  final count = points.length + fc.length;
  const height = 120.0;
  final labels = [
    for (final p in points) c.shortLabel(p.period),
    for (final f in fc) c.shortLabel(f.period),
  ];
  final every = math.max(1, (count / 8).ceil());
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 52,
            height: height,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(c.format(hi), style: const pw.TextStyle(fontSize: 7)),
                pw.Text(c.format(lo), style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.CustomPaint(
              size: const PdfPoint(double.infinity, height),
              painter: (canvas, size) {
                double x(int i) => size.x * i / math.max(1, count - 1);
                double y(double v) => size.y * (v - lo) / (hi - lo);
                canvas
                  ..setStrokeColor(PdfColors.grey300)
                  ..setLineWidth(0.5);
                for (var t = 0; t <= 2; t++) {
                  final gy = size.y * t / 2;
                  canvas
                    ..moveTo(0, gy)
                    ..lineTo(size.x, gy)
                    ..strokePath();
                }
                final current = points.length - 1;
                if (fc.isNotEmpty) {
                  canvas.setFillColor(PdfColors.teal100);
                  final anchor = points[current].value;
                  final start = anchor == null ? fc.first.value : anchor.toDouble();
                  canvas.moveTo(x(current), y(start));
                  for (var k = 0; k < fc.length; k++) {
                    canvas.lineTo(x(current + 1 + k), y(fc[k].high));
                  }
                  for (var k = fc.length - 1; k >= 0; k--) {
                    canvas.lineTo(x(current + 1 + k), y(fc[k].low));
                  }
                  canvas
                    ..closePath()
                    ..fillPath();
                  canvas
                    ..setStrokeColor(_projection)
                    ..setLineWidth(1.6)
                    ..setLineDashPattern([4, 3])
                    ..moveTo(x(current), y(start));
                  for (var k = 0; k < fc.length; k++) {
                    canvas.lineTo(x(current + 1 + k), y(fc[k].value));
                  }
                  canvas
                    ..strokePath()
                    ..setLineDashPattern();
                }
                canvas
                  ..setStrokeColor(_accent)
                  ..setLineWidth(1.8);
                var open = false;
                for (var i = 0; i < points.length; i++) {
                  final v = points[i].value;
                  if (v == null) {
                    if (open) canvas.strokePath();
                    open = false;
                    continue;
                  }
                  if (!open) {
                    canvas.moveTo(x(i), y(v.toDouble()));
                    open = true;
                  } else {
                    canvas.lineTo(x(i), y(v.toDouble()));
                  }
                }
                if (open) canvas.strokePath();
                for (var i = 0; i < points.length; i++) {
                  final v = points[i].value;
                  if (v == null) continue;
                  canvas
                    ..setFillColor(points[i].partial ? PdfColors.white : _accent)
                    ..setStrokeColor(_accent)
                    ..setLineWidth(1.2)
                    ..drawEllipse(x(i), y(v.toDouble()), 2.4, 2.4)
                    ..fillAndStrokePath();
                }
              },
            ),
          ),
        ],
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 56, top: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < labels.length; i++)
              if (i % every == 0 || i == points.length - 1)
                pw.Text(labels[i], style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
      ),
    ],
  );
}

List<pw.Widget> _bars(BiDashboardContent c) {
  final top = c.bars
      .map((b) => b.bar.value?.abs().toDouble() ?? 0)
      .fold<double>(0, math.max);
  return [
    for (final b in c.bars)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${c.kindLabel(b.bar.kind)} · ${c.periodLabel(b.bar.period)} — '
              '${b.bar.value == null ? c.noDataLabel : c.format(b.bar.value!)}'
              '${b.bar.partial ? ' · ${c.partialLabel}' : ''}'
              '${b.change == null ? '' : '  (${b.change})'}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 2),
            pw.Stack(
              children: [
                pw.Container(height: 7, color: PdfColors.grey200),
                pw.LayoutBuilder(
                  builder: (context, constraints) => pw.Container(
                    height: 7,
                    width:
                        (constraints?.maxWidth ?? 0) *
                        (b.bar.value == null || top == 0
                            ? 0
                            : (b.bar.value!.abs() / top).clamp(0.0, 1.0)),
                    color: b.bar.kind == BiBarKind.current ? _accent : PdfColors.blueGrey400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
  ];
}

List<pw.Widget> _composition(BiCompositionContent comp) {
  final widgets = <pw.Widget>[
    pw.SizedBox(height: 6),
    pw.Text(comp.title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 4),
  ];
  if (comp.none != null) {
    return [...widgets, pw.Text(comp.none!, style: const pw.TextStyle(fontSize: 9))];
  }
  const palette = [
    PdfColors.deepOrange700,
    PdfColors.teal600,
    PdfColors.indigo400,
    PdfColors.amber700,
    PdfColors.pink400,
    PdfColors.lightGreen700,
    PdfColors.blueGrey400,
  ];
  PdfColor colorOf(int i) =>
      comp.shares[i].isOther ? PdfColors.grey500 : palette[i % palette.length];
  return [
    ...widgets,
    pw.Text(
      '${comp.centreValue} ${comp.centreLabel}',
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 3),
    // The whole as one bar: each part's width is its share.
    pw.Row(
      children: [
        for (var i = 0; i < comp.shares.length; i++)
          pw.Expanded(
            flex: math.max(1, (comp.shares[i].share * 1000).round()),
            child: pw.Container(height: 10, color: colorOf(i)),
          ),
      ],
    ),
    pw.SizedBox(height: 4),
    for (var i = 0; i < comp.shares.length; i++)
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          children: [
            pw.Container(width: 8, height: 8, color: colorOf(i)),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Text(comp.shares[i].label, style: const pw.TextStyle(fontSize: 9)),
            ),
            pw.Text(
              comp.formatShare!(comp.shares[i].share),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              comp.formatValue!(comp.shares[i].value),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
  ];
}
