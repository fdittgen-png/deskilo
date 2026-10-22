// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'address_window.dart';
import 'invoice.dart';
import 'invoice_pdf.dart';
import 'invoice_pdf_body.dart';
import 'invoice_pdf_style.dart';
import 'invoice_report.dart';
import 'invoice_sales_tax.dart';
import 'report_block_widgets.dart';
import 'report_page_footer.dart';
import 'vat_rate.dart';

/// #837 — ONE invoice's sheets. Used for the document itself and then once
/// per appended reference, so every annex starts on a fresh page and can
/// never overlap the pages before it. One method per part of the sheet.
class InvoiceSheet {
  InvoiceSheet(
    this.request,
    this.theme, {
    required this.invoice,
    required this.proforma,
    required this.copy,
    required this.report,
    required this.dateLabel,
    required this.periodLabel,
    this.watermarkOverride,
    // #869 — only the sheet that goes in the envelope carries the
    // address window; an annex is documentation behind it.
    this.primary = false,
  });

  final InvoicePdfRequest request;
  final pw.ThemeData theme;
  final Invoice invoice;
  final bool proforma;
  final bool copy;
  final InvoiceReport? report;
  final String dateLabel;
  final String periodLabel;
  final String? watermarkOverride;
  final bool primary;

  InvoicePdfStrings get strings => request.strings;
  AddressWindow get addressWindow => request.addressWindow;
  Map<String, Uint8List> get reportImages => request.reportImages;
  String Function(int cents) get money => request.money;
  String Function(InvoiceLine line) get lineText => request.lineText;
  String Function(InvoiceDetailEntry entry) get activityText =>
      request.activityText;

  bool get windowOn => primary && addressWindow.isOn;
  String get numberLine => proforma
      ? (invoice.number.isEmpty
          ? strings.proforma
          : '${strings.proforma} · ${invoice.number}')
      : '${strings.invoiceTitle} ${invoice.number}';
  String get issuedOnLine => '${strings.issuedOn} $dateLabel';
  String get issuedByLine => '${strings.issuedBy} ${invoice.issuerName}';
  String get replacesLine => '${strings.replaces} ${invoice.replacesNumber}';

  int get chargesCents => invoice.lines
      .where((l) => l.amountCents > 0)
      .fold(0, (sum, l) => sum + l.amountCents);
  int get paymentsCents => invoice.lines
      .where((l) => l.amountCents < 0)
      .fold(0, (sum, l) => sum + l.amountCents);
  // The VAT contained in the charges (0072). Prices are VAT-inclusive, so
  // the breakdown EXPLAINS the total rather than adding to it — which is
  // why the net sits above the charges line, not beside it.
  List<InvoiceVatTotal> get vatTotals =>
      invoice.vatTotals.where((t) => t.vatCents > 0).toList();
  bool get showVat => vatTotals.isNotEmpty;

  /// The per-line rate column: VAT documents only (a sales-tax line quotes a net price).
  bool get showRates => showVat && !invoice.isSalesTax;

  /// '20 %', '5.5 %' — beside the caption, so one row reads 'VAT 20 %'.
  String ratePercent(double percent) =>
      '${percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent} %';

  late final List<pw.Widget> headerWidgets = _headerWidgets();
  late final List<pw.Widget> windowHeaderWidgets = _windowHeaderWidgets();
  late final List<pw.Widget> footerWidgets = _footerWidgets();
  late final pw.Widget continuationHeader = _continuationHeader();
  late final InvoiceSheetBody _sections = InvoiceSheetBody(this);
  late final pw.Widget windowRecipient = addressWindowRecipient(
      name: invoice.clientName, address: invoice.memberAddress);

  // An erroneous invoice must be unmistakable even at arm's length, or
  // photocopied, or seen upside down on someone's desk (0071): the word
  // runs across the whole sheet, diagonally, BEHIND the content — every
  // page of it, annex included.
  // #837 — an appended reference carries the stamp that says where it
  // went; everything else follows the document's own state.
  // #917 — the development mark is absolute: even an appended annex,
  // which normally carries the stamp saying where it went, is first of
  // all a page that is not real.
  late final String watermark = _stamp();
  // Its size follows its LENGTH: 'ERRATA' and 'FEHLERHAFT' must both land
  // inside the sheet. (The package's own Watermark scales to the rotated
  // bounding box it computes, which runs the ends off the corners.)
  late final double markSize =
      math.min(120.0, 820 / math.max(watermark.length, 1));

  String _stamp() =>strings.development.isNotEmpty
        ? strings.development.toUpperCase()
        : watermarkOverride ??
            invoiceWatermark(
              strings,
              proforma: proforma,
              voided: invoice.isVoided,
              copy: copy,
            );

  /// #470: the header band replaces the letterhead wholesale.
  List<pw.Widget> _headerWidgets() {
    final report = this.report;
    return report == null
        ? <pw.Widget>[
          // ── Letterhead ────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(invoice.workspaceName,
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfInk)),
                    if (invoice.workspaceAddress.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 3),
                        child: pw.Text(invoice.workspaceAddress,
                            style: const pw.TextStyle(
                                fontSize: 9, color: pdfMuted)),
                      ),
                  ],
                ),
              ),
              // #873 — with a window envelope the identification block
              // does NOT sit up here: the spec puts it under the sender
              // at 90 mm, so it is the first thing in the flow instead.
              if (windowOn)
                pw.SizedBox()
              else
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(numberLine,
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfAccent)),
                  pw.SizedBox(height: 3),
                  pw.Text(issuedOnLine,
                      style: const pw.TextStyle(fontSize: 9, color: pdfMuted)),
                  pw.Text(issuedByLine,
                      style: const pw.TextStyle(fontSize: 9, color: pdfMuted)),
                  if (invoice.replacesNumber.isNotEmpty)
                    pw.Text(replacesLine,
                        style:
                            const pw.TextStyle(fontSize: 9, color: pdfMuted)),
                ],
              ),
            ],
          ),
          pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 14),
              height: 2,
              color: pdfAccent),
        ]
        : reportBlockWidgets(report.header, images: reportImages);
  }

  /// #923 — inside the envelope's 25 mm sender band a picture the design
  /// did not size gets a ceiling, so the letterhead fits instead of
  /// being cut off at the top where the logo lives.
  List<pw.Widget> _windowHeaderWidgets() {
    final report = this.report;
    return report == null
        ? headerWidgets
        : reportBlockWidgets(report.header,
            images: reportImages, maxImageHeight: senderLogoMaxHeight);
  }

  List<pw.Widget> _footerWidgets() {
    final report = this.report;
    return report == null
        ? const <pw.Widget>[]
        : reportBlockWidgets(report.footer, images: reportImages);
  }

  /// #872 — what a page 2 says when the design does not say it: the
  /// document's own title and number over a hairline. Enough to pair a
  /// loose sheet with the invoice it belongs to, and nothing more.
  pw.Widget _continuationHeader() {
    final report = this.report;
    return report != null &&
            report.continuation.isNotEmpty
        ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: reportBlockWidgets(report.continuation,
                images: reportImages),
          )
        : pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: pdfHairline)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(invoice.workspaceName,
                    style: const pw.TextStyle(fontSize: 8, color: pdfMuted)),
                pw.Text(numberLine,
                    style: const pw.TextStyle(fontSize: 8, color: pdfMuted)),
              ],
            ),
          );
  }

  /// Adds this invoice's sheet to [doc].
  void addTo(pw.Document doc) {
    doc.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(),
        // #872 — the letterhead is page furniture, not flow: page one
        // carries it (and reserves the envelope window under it), every
        // later page carries the short strip that says which document
        // this is instead of repeating an address block nobody rereads.
        header: _header,
        // #872 — and the footer is pinned to EVERY page, so the terms,
        // the account to pay into and the page number are on whichever
        // sheet the reader is holding.
        footer: (context) => reportPageFooter(context,
            content: footerWidgets, pageLabel: strings.page),
        build: _body,
      ),
    );
  }

  pw.PageTheme _pageTheme() => pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          // #873 — 20 mm all round: the sender block sits at 20 mm
          // from the top and left edges, which the spec fixes.
          margin: const pw.EdgeInsets.all(pageMargin),
          buildBackground: !windowOn
              ? null
              : (context) => addressWindowBackground(
                    addressWindow,
                    pageNumber: context.pageNumber,
                    child: windowRecipient,
                  ),
          buildForeground: watermark.isEmpty
              ? null
              : (context) => pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Opacity(
                      opacity: pdfWatermarkOpacity,
                      child: pw.Center(
                        child: pw.Transform.rotate(
                          angle: math.pi / 4,
                          child: pw.Text(
                            watermark,
                            style: pw.TextStyle(
                              fontSize: markSize,
                              color: pdfWatermark,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
        );

  pw.Widget _header(pw.Context context) => context.pageNumber == 1
            ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  if (windowOn)
                    // The sender block owns 20 mm → 45 mm, and the flow
                    // resumes at 90 mm: below the 85 × 40 mm aperture
                    // AND below the tolerance band under it.
                    //
                    // #923 — 25 mm is not much, and a letterhead with a
                    // LOGO in it is taller than that. Left to overflow,
                    // the column was clipped and the logo — the first
                    // thing in the band — vanished, while the text lines
                    // under it survived: the owner saw their mark in the
                    // quick view and the designer, and never on the
                    // document. The band is fixed by the envelope spec
                    // and cannot grow, so the letterhead SCALES to fit
                    // it instead of being cut off.
                    //
                    // #965 — capping the picture was not enough: a
                    // heading, a blank line, the logo and three lines of
                    // identity still overran the band, and this time the
                    // logo AND the lines under it vanished while the
                    // heading survived. The band now really scales: the
                    // whole letterhead is laid out at page width and
                    // shrunk uniformly until it fits, so everything the
                    // design says is on the page, smaller if it must be.
                    pw.SizedBox(
                      height: addressWindowTop - pageMargin,
                      child: pw.FittedBox(
                        fit: pw.BoxFit.scaleDown,
                        alignment: pw.Alignment.topLeft,
                        child: pw.SizedBox(
                          width: context.page.pageFormat.availableWidth,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            mainAxisSize: pw.MainAxisSize.min,
                            children: windowHeaderWidgets,
                          ),
                        ),
                      ),
                    )
                  else
                    ...headerWidgets,
                  if (windowOn)
                    pw.SizedBox(
                        height: addressWindowFlowResume - addressWindowTop),
                ],
              )
            : continuationHeader;

  List<pw.Widget> _body(pw.Context context) {
    final report = this.report;
    return [
      ..._identification(),
      ..._voidedBanner(),
      // #470: the body band replaces billed-to, positions and
      // totals — the detail band of the report.
      ...(report == null
          ? <pw.Widget>[
              _sections.billedTo(),
              pw.SizedBox(height: 16),
              _sections.positions(),
              pw.SizedBox(height: 10),
              _sections.totals(),
            ]
          : reportBlockWidgets(report.body, images: reportImages)),
      ..._sections.annex(),
      pw.SizedBox(height: 24),
      ..._signature(),
    ];
  }

  /// #873 — "Facture", its number and the dates, at 90 mm: the first thing
  /// under the address field, as the spec requires.
  List<pw.Widget> _identification() {
    if (!(windowOn && report == null)) return const <pw.Widget>[];
    return [
            pw.Text(numberLine,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: pdfAccent)),
            pw.SizedBox(height: 3),
            pw.Text(issuedOnLine,
                style: const pw.TextStyle(fontSize: 9, color: pdfMuted)),
            pw.Text(issuedByLine,
                style: const pw.TextStyle(fontSize: 9, color: pdfMuted)),
            if (invoice.replacesNumber.isNotEmpty)
              pw.Text(replacesLine,
                  style: const pw.TextStyle(fontSize: 9, color: pdfMuted)),
            pw.SizedBox(height: 12),
    ];
  }

  /// ── Erroneous banner (0061) ──
  List<pw.Widget> _voidedBanner() {
    if (!(invoice.isVoided && !proforma)) return const <pw.Widget>[];
    return [
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: pdfAccent),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Text(strings.voided,
                  style: pw.TextStyle(
                      fontSize: 10,
                      color: pdfAccent,
                      fontWeight: pw.FontWeight.bold)),
            )
    ];
  }

  /// ── Digital signature ── A proforma has none: nothing was issued, so
  /// there is nothing to fingerprint.
  List<pw.Widget> _signature() {
    if (proforma) return const <pw.Widget>[];
    return [
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: pdfHairline)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(strings.signature,
                    style: const pw.TextStyle(fontSize: 7, color: pdfMuted)),
                pw.Text(invoice.signature,
                    style: const pw.TextStyle(fontSize: 7, color: pdfMuted)),
              ],
            ),
          )
    ];
  }
}
