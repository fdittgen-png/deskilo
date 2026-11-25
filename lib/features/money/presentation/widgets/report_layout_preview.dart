// SPDX-License-Identifier: AGPL-3.0-or-later
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

import 'package:deskilo_document_model/layout_model.dart';
import 'package:deskilo_document_model/layout_units.dart';
import 'package:deskilo_document_model/paper.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/address_window.dart';
import '../../domain/invoice_report.dart';
import 'report_page_style.dart';
import 'report_preview.dart';

/// One sheet of the document's paper (#4119: A4 or Letter), at [ReportPage]
/// size, drawing [document].
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
    // #4119 -- the sheet of the document's own paper.
    final paper = document.paper;
    final pageW = ReportPage.widthOf(paper);
    final pageH = ReportPage.heightOf(paper);
    final margin = document.margin.resolve(pageW);
    final contentW = pageW - 2 * margin;
    final contentH = pageH - 2 * margin;

    final g = _Geometry(document, pageW, pageH, margin, contentH);
    final windowOn = g.windowOn;
    final field = g.field;
    final fieldLeft = g.fieldLeft;
    final fieldTop = g.fieldTop;
    final fieldW = g.fieldW;
    final fieldH = g.fieldH;
    final headerH = g.headerH;
    final reserve = g.reserve;
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
                if (headerH == null) box.zone(document.header) else SizedBox(
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
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(pageOne, style: ReportPage.small),
                ),
              ),
            ],
          ),
        ),
        // The recipient, at page coordinates — page one only.
        if (windowOn && !showContinuation)
          Positioned(
            key: const ValueKey('layout-preview-recipient-field'),
            left: fieldLeft,
            top: fieldTop,
            width: fieldW,
            height: fieldH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipientName,
                    style: ReportPage.body.copyWith(fontSize: field.fontSizePt)),
                if (recipientAddress.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(recipientAddress,
                        style: ReportPage.body.copyWith(fontSize: field.fontSizePt)),
                  ),
              ],
            ),
          ),
      ]),
    );
  }
}

/// Where the recipient's field is on the sheet and what it does to the
/// header band and the body's start, on the document's paper (#4119, #3981):
/// the PDF's `RecipientPlacement` without the text measure.
class _Geometry {
  _Geometry(
    LayoutDocument document,
    double pageW,
    double pageH,
    double margin,
    double contentH,
  ) {
    final paper = document.paper;
    final recipient = document.recipient;
    final window = recipient?.window;
    final frame = recipient?.frame;
    windowOn =
        recipient != null &&
        !recipient.isOff &&
        (window != null || frame != null);
    field = (window ?? AddressWindow.off).fieldOn(paper);
    fieldLeft =
        frame?.x?.resolve(pageW) ??
        (window != null && window.isOn ? field.leftPt : 0.0);
    fieldTop = frame?.y?.resolve(pageH) ?? field.topPt;
    fieldW = frame?.w?.resolve(pageW) ?? field.widthPt;
    fieldH = frame?.h?.resolve(pageH) ?? field.heightPt;
    headerH =
        document.header.height?.resolve(contentH) ??
        (windowOn
            ? (frame?.y != null ? fieldTop : field.senderLimitPt) - margin
            : null);
    // A body stated at the A4 convention's 90 mm under a named window
    // means where the window convention resumes: on Letter, its own line.
    final stated = document.body.y;
    final followsWindow =
        paper != Paper.a4 &&
        windowOn &&
        frame == null &&
        stated != null &&
        stated.unit == LengthUnit.mm &&
        stated.value == addressWindowFlowResumeMm;
    final bodyTop = followsWindow
        ? field.flowResumePt
        : stated?.resolve(pageH) ?? (windowOn ? field.flowResumePt : null);
    reserve = bodyTop == null
        ? 0.0
        : (bodyTop - margin - (headerH ?? 0)).clamp(0.0, pageH);
  }

  late final bool windowOn;
  late final AddressField field;
  late final double fieldLeft, fieldTop, fieldW, fieldH, reserve;
  late final double? headerH;
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
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                  padding: EdgeInsets.only(left: i == 0 ? 0 : AppSpacing.lg),
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
