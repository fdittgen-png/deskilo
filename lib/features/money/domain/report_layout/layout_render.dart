// SPDX-License-Identifier: 0BSD
//
// #875 — the positioned engine: a [LayoutDocument] to a PDF.
//
// The banded engine let position fall out of flow. Here every zone and
// every element resolves its own lengths against the box it sits in,
// so a design that says `x="110mm" y="45mm"` lands there, and the
// conformance harness can measure that it did. The four zones keep the
// #872 contract — header on page one, continuation after, footer on
// every page, body the only thing that flows — because the design says
// so, not because the engine assumed it.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:liquify/liquify.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../address_window.dart';
import '../invoice_pdf_template.dart';
import '../invoice_report.dart';
import '../report_block_widgets.dart';
import '../report_style.dart';
import 'layout_model.dart';
import 'layout_units.dart';
import 'layout_xml.dart';

/// The Liquid pass, then the XML parse — the same order the bands use.
///
/// String VALUES are XML-escaped before Liquid sees them, so a member
/// called "Smith & Sons" cannot turn the document into something that
/// is no longer XML. The template itself is never escaped: it IS the
/// XML. Placeholders are seeded first (#875), so an absent one is empty
/// rather than nil and a guarded element vanishes cleanly.
LayoutDocument renderLayoutDocument(
  String xml,
  Map<String, Object?> data,
) {
  final seeded = <String, Object?>{
    ...InvoicePdfTemplate.placeholderDefaults,
    ...data,
  };
  final String rendered;
  try {
    rendered =
        Template.parse(xml, data: Map.of(_xmlEscaped(seeded))).render();
  } catch (e, st) {
    throw LayoutException(LayoutError.liquid, '$e', cause: e, stackTrace: st);
  }
  return parseLayoutXml(rendered);
}

Map<String, Object?> _xmlEscaped(Map<String, Object?> data) =>
    {for (final e in data.entries) e.key: _escapeValue(e.value)};

Object? _escapeValue(Object? v) => switch (v) {
      String s => s
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;'),
      List l => [for (final x in l) _escapeValue(x)],
      Map m => {for (final e in m.entries) '${e.key}': _escapeValue(e.value)},
      _ => v,
    };

/// Renders [document] to A4 pages.
///
/// [data] is the unescaped map the recipient block reads its name and
/// address from. The legal chrome the bands never templated — the
/// watermark and the digital signature — stays non-templated here too:
/// it is passed in, never designed.
Future<Uint8List> buildLayoutPdf({
  required LayoutDocument document,
  required Map<String, Object?> data,
  required String documentTitle,
  required String pageLabel,
  required pw.Font baseFont,
  required pw.Font boldFont,
  Map<String, Uint8List> images = const {},
  String watermark = '',
  String signatureLabel = '',
  String signature = '',
}) async {
  final pageW = PdfPageFormat.a4.width;
  final pageH = PdfPageFormat.a4.height;
  final margin = document.margin.resolve(pageW);
  final contentW = pageW - 2 * margin;
  final contentH = pageH - 2 * margin;
  final ctx = _Box(contentW, contentH, images);

  // The recipient: a named convention takes the millimetres from the one
  // place they live; an explicit frame is page-absolute by definition.
  final recipient = document.recipient;
  final window = recipient?.window;
  final recipientFrame = recipient?.frame;
  final windowOn =
      recipient != null && !recipient.isOff && (window != null || recipientFrame != null);
  final fieldLeft = recipientFrame?.x?.resolve(pageW) ??
      (window != null && window.isOn ? window.leftEdge : 0.0);
  final fieldTop = recipientFrame?.y?.resolve(pageH) ?? addressWindowTop;
  final fieldW = recipientFrame?.w?.resolve(pageW) ?? addressWindowWidth;
  final fieldH = recipientFrame?.h?.resolve(pageH) ?? addressWindowHeight;

  // The header owns the band above the field; the body resumes where
  // the design says, or at 90 mm under a window, or right after the
  // header otherwise.
  final headerH = document.header.height?.resolve(contentH) ??
      (windowOn ? fieldTop - margin : null);
  final bodyTop = document.body.y?.resolve(pageH) ??
      (windowOn ? addressWindowFlowResume : null);
  final reserve = bodyTop == null
      ? 0.0
      : math.max(0.0, bodyTop - margin - (headerH ?? 0));

  final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
  final doc = pw.Document(title: documentTitle);
  final markSize = math.min(120.0, 820 / math.max(watermark.length, 1));

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: pw.EdgeInsets.all(margin),
        buildBackground: !windowOn
            ? null
            : (context) => context.pageNumber != 1
                ? pw.SizedBox()
                : pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Stack(children: [
                      pw.Positioned(
                        left: fieldLeft,
                        top: fieldTop,
                        child: pw.SizedBox(
                          width: fieldW,
                          height: fieldH,
                          child: addressWindowRecipient(
                            name: '${data['member'] ?? ''}',
                            address: '${data['client_address'] ?? ''}',
                          ),
                        ),
                      ),
                    ]),
                  ),
        buildForeground: watermark.isEmpty
            ? null
            : (context) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Opacity(
                    opacity: 0.5,
                    child: pw.Center(
                      child: pw.Transform.rotate(
                        angle: math.pi / 4,
                        child: pw.Text(watermark,
                            style: pw.TextStyle(
                                fontSize: markSize,
                                color: PdfColors.grey400,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
      ),
      header: (context) => context.pageNumber == 1
          ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                headerH == null
                    ? ctx.zone(document.header)
                    : ctx.zone(document.header,
                        height: headerH, clip: true, context: context),
                if (reserve > 0) pw.SizedBox(height: reserve),
              ],
            )
          : ctx.zone(document.continuation,
              height: document.continuation.height?.resolve(contentH)),
      footer: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          ctx.zone(document.footer,
              height: document.footer.height?.resolve(contentH)),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              '$pageLabel ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(
                  fontSize: reportSmallSize, color: reportMuted),
            ),
          ),
        ],
      ),
      build: (context) => [
        ...ctx.children(document.body.children, height: contentH),
        if (signature.isNotEmpty) ...[
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: reportHairline)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(signatureLabel,
                    style: const pw.TextStyle(
                        fontSize: 7, color: reportMuted)),
                pw.Text(signature,
                    style: const pw.TextStyle(
                        fontSize: 7, color: reportMuted)),
              ],
            ),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

/// The box an element resolves against: its parent's width and height,
/// and the image library.
class _Box {
  const _Box(this.w, this.h, this.images);
  final double w;
  final double h;
  final Map<String, Uint8List> images;

  _Box inner(double? w, double? h) => _Box(w ?? this.w, h ?? this.h, images);

  /// A zone: flowing children stacked, positioned children in a Stack
  /// of the zone's height — or, in a zone without one, tall enough for
  /// the lowest of them.
  ///
  /// A declared [height] is a MINIMUM. Content taller than it grows the
  /// zone; it is never dropped. A footer with one line too many used to
  /// vanish entirely — rule, bank block, reference, all of it — because
  /// the engine was handed a box the content did not fit, and a footer
  /// that is not there is worse than one that is a little tall. When
  /// [clip] is set the box IS fixed and the overflow is cut instead:
  /// that is the page-1 letterhead, which must stop above the envelope
  /// window whatever it contains.
  pw.Widget zone(
    LayoutZone zone, {
    double? height,
    bool clip = false,
    pw.Context? context,
  }) {
    if (zone.isEmpty) return pw.SizedBox(height: height ?? 0);
    var widgets = children(zone.children, height: height ?? h);
    if (height != null && clip && context != null) {
      // A clip path would hide the overflow on paper but the text
      // operators would still be in the file — a screen reader, a
      // search, or the conformance harness would all find a letterhead
      // "in the window". So the overflow is never emitted: children are
      // laid out one by one and kept only while they fit the box.
      widgets = _fitting(widgets, context, height);
    }
    final column = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: widgets,
    );
    if (height == null) return column;
    if (clip) return pw.SizedBox(height: height, child: column);
    return pw.ConstrainedBox(
      constraints: pw.BoxConstraints(minHeight: height),
      child: column,
    );
  }

  /// The longest prefix of [widgets] whose laid-out heights fit [height]
  /// at this box's width.
  List<pw.Widget> _fitting(
      List<pw.Widget> widgets, pw.Context context, double height) {
    final kept = <pw.Widget>[];
    var used = 0.0;
    for (final widget in widgets) {
      widget.layout(context, pw.BoxConstraints(maxWidth: w));
      final own = widget.box?.height ?? 0;
      if (used + own > height + 0.01) break;
      used += own;
      kept.add(widget);
    }
    return kept;
  }

  List<pw.Widget> children(List<LayoutElement> elements,
      {required double height}) {
    final flowing = <pw.Widget>[];
    final positioned = <pw.Widget>[];
    var lowest = 0.0;
    for (final el in elements) {
      if (!el.frame.isPositioned) {
        flowing.add(element(el));
        continue;
      }
      final x = el.frame.x?.resolve(w) ?? 0;
      final y = el.frame.y?.resolve(height) ?? 0;
      final ew = el.frame.w?.resolve(w);
      final eh = el.frame.h?.resolve(height);
      lowest = math.max(lowest, y + (eh ?? reportBodySize * 1.4));
      positioned.add(pw.Positioned(
        left: x,
        top: y,
        child: pw.SizedBox(width: ew ?? (w - x), height: eh,
            child: inner(ew, eh).element(el, sized: true)),
      ));
    }
    return [
      if (positioned.isNotEmpty)
        pw.SizedBox(
          height: math.min(lowest, height),
          child: pw.Stack(children: positioned),
        ),
      ...flowing,
    ];
  }

  pw.Widget element(LayoutElement el, {bool sized = false}) {
    final widget = switch (el) {
      LayoutText(:final text, :final style, :final align, :final bold) =>
        pw.Text(text, textAlign: _align(align), style: _style(style, bold)),
      LayoutImage(:final name, :final fit, :final align) =>
        images[name] == null
            ? pw.SizedBox()
            : pw.Image(
                pw.MemoryImage(images[name]!),
                fit: switch (fit) {
                  LayoutFit.contain => pw.BoxFit.contain,
                  LayoutFit.cover => pw.BoxFit.cover,
                  LayoutFit.fill => pw.BoxFit.fill,
                },
                alignment: switch (align) {
                  LayoutAlign.left => pw.Alignment.centerLeft,
                  LayoutAlign.center => pw.Alignment.center,
                  LayoutAlign.right => pw.Alignment.centerRight,
                },
              ),
      LayoutRule() => pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 8),
          height: reportRuleThickness,
          color: reportAccent),
      LayoutSpacer(:final size) =>
        pw.SizedBox(height: size?.resolve(h) ?? reportSpacerSize),
      LayoutTable(:final columns, :final rows) => _table(columns, rows),
      LayoutBox(:final children) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: this.children(children, height: h)),
      LayoutColumns(:final columns) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns.length; i++)
              pw.Expanded(
                child: pw.Padding(
                  padding: pw.EdgeInsets.only(left: i == 0 ? 0 : 16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: inner(w / columns.length, null)
                        .children(columns[i], height: h),
                  ),
                ),
              ),
          ],
        ),
      LayoutMarkup(:final source) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children:
              reportBlockWidgets(parseReportMarkup(source), images: images)),
    };
    // A flowing element with a width or height still honours it.
    if (sized || (el.frame.w == null && el.frame.h == null)) return widget;
    return pw.SizedBox(
      width: el.frame.w?.resolve(w),
      height: el.frame.h?.resolve(h),
      child: widget,
    );
  }

  pw.Widget _table(List<LayoutColumn> columns, List<LayoutRow> rows) {
    final count = columns.isEmpty
        ? rows.fold(0, (m, r) => math.max(m, r.cells.length))
        : columns.length;
    return pw.Table(
      columnWidths: {
        for (var i = 0; i < count; i++)
          i: i < columns.length && columns[i].w != null
              ? (columns[i].w!.isRelative
                  ? pw.FractionColumnWidth(columns[i].w!.value / 100)
                  : pw.FixedColumnWidth(columns[i].w!.resolve(w)))
              : const pw.FlexColumnWidth(),
      },
      children: [
        for (final row in rows)
          pw.TableRow(children: [
            for (var i = 0; i < count; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: i < row.cells.length
                    ? pw.Text(
                        row.cells[i].text,
                        textAlign: _align(row.cells[i].align ??
                            (i < columns.length
                                ? columns[i].align
                                : LayoutAlign.left)),
                        style: _style(LayoutStyle.body, row.bold),
                      )
                    : pw.SizedBox(),
              ),
          ]),
      ],
    );
  }
}

pw.TextAlign _align(LayoutAlign a) => switch (a) {
      LayoutAlign.left => pw.TextAlign.left,
      LayoutAlign.center => pw.TextAlign.center,
      LayoutAlign.right => pw.TextAlign.right,
    };

pw.TextStyle _style(LayoutStyle s, bool bold) => switch (s) {
      LayoutStyle.heading => pw.TextStyle(
          fontSize: reportHeadingSize,
          fontWeight: pw.FontWeight.bold,
          color: reportInk),
      LayoutStyle.subheading => pw.TextStyle(
          fontSize: reportSubheadingSize,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: reportSubheadingTracking,
          color: reportMuted),
      LayoutStyle.body => pw.TextStyle(
          fontSize: reportBodySize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: reportInk),
      LayoutStyle.small => pw.TextStyle(
          fontSize: reportSmallSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: reportMuted),
    };

/// Every image name a document references, so a caller can fetch them
/// from the library before rendering — the same contract as the bands'
/// `reportImageRefs`.
Set<String> layoutImageNames(LayoutDocument document) {
  final names = <String>{};
  void walk(List<LayoutElement> elements) {
    for (final el in elements) {
      switch (el) {
        case LayoutImage(:final name):
          names.add(name);
        case LayoutBox(:final children):
          walk(children);
        case LayoutColumns(:final columns):
          columns.forEach(walk);
        case LayoutText() ||
              LayoutRule() ||
              LayoutSpacer() ||
              LayoutTable() ||
              LayoutMarkup():
          break;
      }
    }
  }

  for (final zone in [
    document.header,
    document.continuation,
    document.body,
    document.footer,
  ]) {
    walk(zone.children);
  }
  return names;
}
