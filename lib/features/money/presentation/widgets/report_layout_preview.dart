// SPDX-License-Identifier: 0BSD
//
// #875 — the page-true mirror of a positioned layout.
//
// The PDF is the truth and the harness measures the PDF; this is what
// the designer LOOKS at while editing. It draws the same tree with the
// same `Length.resolve`, the same zone rules and the same ink tokens
// (`ReportPage`), so geometry is identical by construction — the only
// thing that can differ is text wrapping at the glyph level, and that
// is why the CLI `check` exists.
//
// Page one only: the letterhead band, the aperture, the body and the
// fixed footer at the bottom of an A4 sheet. Later pages are the
// continuation strip over the same body flow; the preview shows the
// strip separately rather than paginating, which the PDF does.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/address_window.dart';
import '../../domain/invoice_report.dart';
import '../../domain/report_layout/layout_model.dart';
import 'report_page_style.dart';
import 'report_preview.dart';

/// One A4 sheet, at [ReportPage] size, drawing [document].
class LayoutPageView extends StatelessWidget {
  const LayoutPageView({
    super.key,
    required this.document,
    required this.data,
    this.images = const {},
    this.showContinuation = false,
    this.pageLabel = 'Page',
  });

  /// The word before the page number, in the reader's language.
  final String pageLabel;

  final LayoutDocument document;

  /// The unescaped data — the recipient block reads its name and
  /// address from here, exactly as the PDF does.
  final Map<String, Object?> data;

  /// Library images by name; an unknown name draws nothing.
  final Map<String, Uint8List> images;

  /// Show the page-2 strip instead of the letterhead.
  final bool showContinuation;

  @override
  Widget build(BuildContext context) {
    const pageW = ReportPage.width;
    const pageH = ReportPage.height;
    final margin = document.margin.resolve(pageW);
    final contentW = pageW - 2 * margin;
    final contentH = pageH - 2 * margin;

    final recipient = document.recipient;
    final window = recipient?.window;
    final frame = recipient?.frame;
    final windowOn = recipient != null &&
        !recipient.isOff &&
        (window != null || frame != null);
    final fieldLeft = frame?.x?.resolve(pageW) ??
        (window != null && window.isOn ? window.leftEdge : 0.0);
    final fieldTop = frame?.y?.resolve(pageH) ?? addressWindowTop;
    final fieldW = frame?.w?.resolve(pageW) ?? addressWindowWidth;
    final fieldH = frame?.h?.resolve(pageH) ?? addressWindowHeight;

    final headerH = document.header.height?.resolve(contentH) ??
        (windowOn ? fieldTop - margin : null);
    final bodyTop = document.body.y?.resolve(pageH) ??
        (windowOn ? addressWindowFlowResume : null);
    final reserve = bodyTop == null
        ? 0.0
        : (bodyTop - margin - (headerH ?? 0)).clamp(0.0, pageH);
    final footerH = document.footer.height?.resolve(contentH);
    final pageOne = '$pageLabel 1';
    // The recipient reads the same two fields the PDF reads.
    final recipientName = '${data['member'] ?? ''}';
    final recipientAddress = '${data['client_address'] ?? ''}';

    final box = _Box(contentW, contentH, images);
    return Container(
      width: pageW,
      height: pageH,
      color: ReportPage.paper,
      child: Stack(children: [
        // The flow: letterhead (or strip), the reserved band, the body.
        Positioned(
          left: margin,
          top: margin,
          width: contentW,
          bottom: margin + (footerH ?? 0) + 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showContinuation)
                box.zone(document.continuation,
                    height: document.continuation.height?.resolve(contentH))
              else ...[
                headerH == null
                    ? box.zone(document.header)
                    : SizedBox(
                        height: headerH,
                        child: box.zone(document.header, height: headerH)),
                if (reserve > 0) SizedBox(height: reserve),
              ],
              Expanded(
                child: ClipRect(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: box.children(document.body.children,
                        height: contentH),
                  ),
                ),
              ),
            ],
          ),
        ),
        // The fixed footer, bottom of the sheet.
        Positioned(
          left: margin,
          right: margin,
          bottom: margin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              box.zone(document.footer, height: footerH),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(pageOne, style: ReportPage.small),
                ),
              ),
            ],
          ),
        ),
        // The recipient, at page coordinates — page one only.
        if (windowOn && !showContinuation)
          Positioned(
            left: fieldLeft,
            top: fieldTop,
            width: fieldW,
            height: fieldH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipientName,
                    style: ReportPage.body.copyWith(fontSize: 11)),
                if (recipientAddress.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(recipientAddress,
                        style: ReportPage.body.copyWith(fontSize: 11)),
                  ),
              ],
            ),
          ),
      ]),
    );
  }
}

/// The parent box an element resolves against — the Flutter twin of the
/// renderer's `_Box`, kept structurally identical on purpose.
class _Box {
  const _Box(this.w, this.h, this.images);
  final double w;
  final double h;
  final Map<String, Uint8List> images;

  _Box inner(double? w, double? h) => _Box(w ?? this.w, h ?? this.h, images);

  Widget zone(LayoutZone zone, {double? height}) {
    if (zone.isEmpty) return SizedBox(height: height ?? 0);
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children(zone.children, height: height ?? h),
      ),
    );
  }

  List<Widget> children(List<LayoutElement> elements,
      {required double height}) {
    final flowing = <Widget>[];
    final positioned = <Widget>[];
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
      lowest = lowest > y + (eh ?? 14) ? lowest : y + (eh ?? 14);
      positioned.add(Positioned(
        left: x,
        top: y,
        width: ew ?? (w - x),
        height: eh,
        child: inner(ew, eh).element(el, sized: true),
      ));
    }
    return [
      if (positioned.isNotEmpty)
        SizedBox(
          height: lowest < height ? lowest : height,
          child: Stack(children: positioned),
        ),
      ...flowing,
    ];
  }

  Widget element(LayoutElement el, {bool sized = false}) {
    final widget = switch (el) {
      LayoutText(:final text, :final style, :final align, :final bold) =>
        Text(text, textAlign: _align(align), style: _style(style, bold)),
      LayoutImage(:final name, :final fit, :final align) =>
        images[name] == null
            ? const SizedBox.shrink()
            : Align(
                alignment: switch (align) {
                  LayoutAlign.left => Alignment.centerLeft,
                  LayoutAlign.center => Alignment.center,
                  LayoutAlign.right => Alignment.centerRight,
                },
                child: Image.memory(images[name]!,
                    fit: switch (fit) {
                      LayoutFit.contain => BoxFit.contain,
                      LayoutFit.cover => BoxFit.cover,
                      LayoutFit.fill => BoxFit.fill,
                    }),
              ),
      LayoutRule() => Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 2,
          color: ReportPage.accent),
      LayoutSpacer(:final size) => SizedBox(height: size?.resolve(h) ?? 8),
      LayoutTable(:final columns, :final rows) => _table(columns, rows),
      LayoutBox(:final children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: this.children(children, height: h)),
      LayoutColumns(:final columns) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: inner(w / columns.length, null)
                        .children(columns[i], height: h),
                  ),
                ),
              ),
          ],
        ),
      LayoutMarkup(:final source) => ReportBlocksView(
          report: InvoiceReport(
              header: const [], body: parseReportMarkup(source), footer: const []),
          images: images,
        ),
    };
    if (sized || (el.frame.w == null && el.frame.h == null)) return widget;
    return SizedBox(
      width: el.frame.w?.resolve(w),
      height: el.frame.h?.resolve(h),
      child: widget,
    );
  }

  Widget _table(List<LayoutColumn> columns, List<LayoutRow> rows) {
    final count = columns.isEmpty
        ? rows.fold(0, (m, r) => r.cells.length > m ? r.cells.length : m)
        : columns.length;
    return Table(
      columnWidths: {
        for (var i = 0; i < count; i++)
          i: i < columns.length && columns[i].w != null
              ? (columns[i].w!.isRelative
                  ? FractionColumnWidth(columns[i].w!.value / 100)
                  : FixedColumnWidth(columns[i].w!.resolve(w)))
              : const FlexColumnWidth(),
      },
      children: [
        for (final row in rows)
          TableRow(children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: i < row.cells.length
                    ? Text(
                        row.cells[i].text,
                        textAlign: _align(row.cells[i].align ??
                            (i < columns.length
                                ? columns[i].align
                                : LayoutAlign.left)),
                        style: ReportPage.row(bold: row.bold),
                      )
                    : const SizedBox.shrink(),
              ),
          ]),
      ],
    );
  }
}

TextAlign _align(LayoutAlign a) => switch (a) {
      LayoutAlign.left => TextAlign.left,
      LayoutAlign.center => TextAlign.center,
      LayoutAlign.right => TextAlign.right,
    };

TextStyle _style(LayoutStyle s, bool bold) => switch (s) {
      LayoutStyle.heading => ReportPage.heading,
      LayoutStyle.subheading => ReportPage.subheading,
      LayoutStyle.body => ReportPage.row(bold: bold),
      LayoutStyle.small => bold
          ? ReportPage.small.copyWith(fontWeight: FontWeight.bold)
          : ReportPage.small,
    };
