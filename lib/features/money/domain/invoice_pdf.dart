// SPDX-License-Identifier: 0BSD
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'invoice.dart';
import 'address_window.dart';
import 'invoice_report.dart';
import 'report_block_widgets.dart';

/// Localized strings the invoice PDF prints.
class InvoicePdfStrings {
  const InvoicePdfStrings({
    required this.invoiceTitle,
    required this.issuedOn,
    required this.issuedBy,
    required this.billedTo,
    required this.total,
    required this.signature,
    required this.voided,
    this.voidedWatermark = '',
    this.proforma = '',
    this.copy = '',
    this.settledIn = '',
    required this.replaces,
    required this.description,
    required this.charges,
    required this.payments,
    this.net = '',
    this.vat = '',
    required this.annex,
    required this.attendance,
    required this.activity,
    required this.reserved,
    required this.page,
  });

  final String invoiceTitle;
  final String issuedOn;
  final String issuedBy;
  final String billedTo;

  /// The bottom line — the solde (0063).
  final String total;
  final String signature;

  /// Banner on an invoice tagged erroneous (0061).
  final String voided;

  /// ONE word for the diagonal watermark of an erroneous invoice — the
  /// banner's sentence is too long to read across a page. '' = no
  /// watermark (kept optional so older callers still compile).
  final String voidedWatermark;

  /// The word a PROFORMA document carries, in its header and across the
  /// page. Only read when [buildInvoicePdf] is asked for a proforma.
  final String proforma;

  /// The word stamped across a COPY — what a member renders of an invoice
  /// they did not issue. Only read when [buildInvoicePdf] is asked for one.
  final String copy;

  /// #831 — the whole watermark of a settled source ("REGROUPED IN
  /// INV-…"); '' on every other document.
  final String settledIn;

  /// Label before the replaced invoice's number on a replacement (0061).
  final String replaces;

  /// Lines-table column header.
  final String description;

  /// Subtotal captions above the balance (0063).
  final String charges;
  final String payments;

  /// VAT captions (0072), only printed when the invoice carries tax: the
  /// net subtotal and the word before each rate ('VAT 20 %'). Defaulted so
  /// a caller from before VAT existed still compiles.
  final String net;
  final String vat;

  /// Annex section titles (0064).
  final String annex;
  final String attendance;
  final String activity;

  /// Suffix on an attendance row that was booked but not attended.
  final String reserved;

  /// Footer page label ('Page').
  final String page;
}

/// Named in the PDF metadata — PDF/A wants a producer, and a reader
/// wondering where a file came from deserves an answer.
const String _producer = 'DesKilo';

/// DesKilo brand accent — matches the launcher icon red.
const PdfColor _accent = PdfColor.fromInt(0xFFD32F2F);
const PdfColor _ink = PdfColors.blueGrey900;
const PdfColor _muted = PdfColors.blueGrey600;
const PdfColor _hairline = PdfColors.blueGrey200;

/// Light grey of the erroneous watermark. Painted at half opacity OVER
/// the content: as a background it disappeared behind the billed-to card
/// and the period box, which swallowed half the word. Over white it lands
/// at the same light grey; over a figure it only greys the stroke, so
/// every amount stays readable.
const PdfColor _watermark = PdfColors.grey400;

const double _watermarkOpacity = 0.5;
const PdfColor _zebra = PdfColor.fromInt(0xFFF6F7F9);

/// The archive PDF of one invoice — professional layout (field
/// request): letterhead with the workspace identity, a boxed billed-to
/// block, a proper positions table with charges/payments subtotals and
/// the SOLDE as the bottom line, and — for detailed invoices (0064) —
/// an annex listing every check-in and every booked movement of the
/// month. Everything renders from the invoice's SNAPSHOT fields; the
/// caller supplies localized wording so this builder stays l10n-free.
/// #837 — one invoice appended to another as documentation: its own
/// pages, its own stamp. [dateLabel] and [periodLabel] are the caller's
/// formatted values, as for the main document.
typedef InvoiceAnnex = ({
  Invoice invoice,
  String dateLabel,
  String periodLabel,
  String watermark,
});

Future<Uint8List> buildInvoicePdf({
  required Invoice invoice,
  required InvoicePdfStrings strings,
  Map<String, Uint8List> reportImages = const {},
  required String Function(int cents) money,
  required String Function(InvoiceLine line) lineText,
  required String Function(InvoiceDetailEntry entry) activityText,
  required String dateLabel,
  required pw.Font baseFont,
  required pw.Font boldFont,
  /// What the invoice COVERS, in words ('July 2026'). The stored
  /// [Invoice.title] is the raw period ('2026-07'), which no reader should
  /// have to decode; empty falls back to it (legacy 0060 free-form titles).
  String periodLabel = '',
  /// Renders the SAME figures as a proforma: a quote for a month, not a
  /// document of record. It carries no signature (there is nothing to
  /// certify), says PROFORMA where an invoice says its number, and wears
  /// the same diagonal watermark so the two can never be confused on a
  /// desk. An issued invoice can also be re-rendered this way — as a
  /// payment request that does not pass for the original.
  bool proforma = false,
  /// Stamps the render as a duplicate: the issuer holds the original, the
  /// member re-renders it on demand. Ignored on a proforma (which is not a
  /// copy of anything) and on an erroneous invoice (whose own stamp wins).
  bool copy = false,
  /// FACTUR-X: the EN 16931 invoice as CII, embedded in the PDF itself.
  /// Turns the document into PDF/A-3 (the format's requirement) carrying
  /// `factur-x.xml` — one file a human reads and a machine parses, which
  /// is what French and German small businesses actually exchange.
  /// Requires [colorProfile] (PDF/A demands an output intent).
  String facturXml = '',

  /// Owner report bands (#454/#470), already rendered by
  /// `renderInvoiceReport`. Null = the built-in layout. PDF only — the
  /// XML never carries them; the void banner/watermark, signature,
  /// annex and page numbers stay non-templated regardless.
  InvoiceReport? report,
  Uint8List? colorProfile,

  /// #837 — invoices appended AFTER this one as reference, in order.
  /// A settlement uses it to carry the invoices it regrouped, each
  /// stamped with the number that now owes their balance.
  List<InvoiceAnnex> annexes = const [],

  /// #869 — where the recipient sits so it shows through a window
  /// envelope. Resolved by the caller from the template and the seller's
  /// country, because only the caller knows both.
  AddressWindow addressWindow = AddressWindow.off,
}) async {
  final hybrid = facturXml.isNotEmpty && colorProfile != null;
  final doc = pw.Document(
    title: '${strings.invoiceTitle} ${invoice.number}',
    author: invoice.workspaceName,
    creator: _producer,
    producer: _producer,
    subject: periodLabel,
    metadata: hybrid
        ? PdfaRdf(
            title: '${strings.invoiceTitle} ${invoice.number}',
            author: invoice.workspaceName,
            creator: _producer,
            producer: _producer,
            subject: periodLabel,
            invoiceRdf: PdfaFacturxRdf().create(
              conformanceLevel: 'EN 16931',
            ),
          ).create()
        : null,
  );
  if (hybrid) {
    // PDF/A-3: an embedded output intent, and the XML as an /Alternative
    // attachment — the two halves of the same invoice.
    PdfaColorProfile(doc.document, colorProfile);
    PdfaAttachedFiles(doc.document, [
      PdfaAttachedFile(
        name: 'factur-x.xml',
        data: facturXml,
        AFRelationship: '/Alternative',
      ),
    ]);
  }
  final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
  // Composed outside the widget calls (HARD RULE #1 lints inline
  // literals).
  // #837 — ONE invoice's sheets. Called for the document itself and then
  // once per appended reference, so every annex starts on a fresh page
  // and can never overlap the pages before it.
  void addSheets({
    required Invoice invoice,
    required bool proforma,
    required bool copy,
    required InvoiceReport? report,
    required String dateLabel,
    required String periodLabel,
    String? watermarkOverride,
    // #869 — only the sheet that goes in the envelope carries the
    // address window; an annex is documentation behind it.
    bool primary = false,
  }) {
    final windowOn = primary && addressWindow.isOn;
    final numberLine = proforma
        ? (invoice.number.isEmpty
            ? strings.proforma
            : '${strings.proforma} · ${invoice.number}')
        : '${strings.invoiceTitle} ${invoice.number}';
    final issuedOnLine = '${strings.issuedOn} $dateLabel';
    final issuedByLine = '${strings.issuedBy} ${invoice.issuerName}';
    final replacesLine = '${strings.replaces} ${invoice.replacesNumber}';

    final chargesCents = invoice.lines
        .where((l) => l.amountCents > 0)
        .fold(0, (sum, l) => sum + l.amountCents);
    final paymentsCents = invoice.lines
        .where((l) => l.amountCents < 0)
        .fold(0, (sum, l) => sum + l.amountCents);
    // The VAT contained in the charges (0072). Prices are VAT-inclusive, so
    // the breakdown EXPLAINS the total rather than adding to it — which is
    // why the net sits above the charges line, not beside it.
    final vatTotals = invoice.vatTotals.where((t) => t.vatCents > 0).toList();
    final showVat = vatTotals.isNotEmpty;
    /// '20 %', '5.5 %' — beside the caption, so one row reads 'VAT 20 %'.
    String ratePercent(double percent) =>
        '${percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent} %';

    // #470: the header band replaces the letterhead wholesale.
    final List<pw.Widget> headerWidgets = report == null
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
                            color: _ink)),
                    if (invoice.workspaceAddress.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 3),
                        child: pw.Text(invoice.workspaceAddress,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
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
                          color: _accent)),
                  pw.SizedBox(height: 3),
                  pw.Text(issuedOnLine,
                      style: const pw.TextStyle(fontSize: 9, color: _muted)),
                  pw.Text(issuedByLine,
                      style: const pw.TextStyle(fontSize: 9, color: _muted)),
                  if (invoice.replacesNumber.isNotEmpty)
                    pw.Text(replacesLine,
                        style:
                            const pw.TextStyle(fontSize: 9, color: _muted)),
                ],
              ),
            ],
          ),
          pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 14),
              height: 2,
              color: _accent),
        ]
        : reportBlockWidgets(report.header, images: reportImages);

    final List<pw.Widget> footerWidgets = report == null
        ? const <pw.Widget>[]
        : reportBlockWidgets(report.footer, images: reportImages);

    // #872 — what a page 2 says when the design does not say it: the
    // document's own title and number over a hairline. Enough to pair a
    // loose sheet with the invoice it belongs to, and nothing more.
    final pw.Widget continuationHeader = report != null &&
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
              border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(invoice.workspaceName,
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
                pw.Text(numberLine,
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
              ],
            ),
          );

    final pw.Widget windowRecipient = addressWindowRecipient(
        name: invoice.clientName, address: invoice.memberAddress);

    pw.Widget label(String text) => pw.Text(text,
        style: pw.TextStyle(
            fontSize: 8,
            color: _muted,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2));

    pw.Widget amountCell(int cents, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          child: pw.Text(money(cents),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 10,
                  color: cents < 0 ? _accent : _ink,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    // An erroneous invoice must be unmistakable even at arm's length, or
    // photocopied, or seen upside down on someone's desk (0071): the word
    // runs across the whole sheet, diagonally, BEHIND the content — every
    // page of it, annex included.
    // #837 — an appended reference carries the stamp that says where it
    // went; everything else follows the document's own state.
    final watermark = watermarkOverride ??
        invoiceWatermark(
          strings,
          proforma: proforma,
          voided: invoice.isVoided,
          copy: copy,
        );
    // Its size follows its LENGTH: 'ERRATA' and 'FEHLERHAFT' must both land
    // inside the sheet. (The package's own Watermark scales to the rotated
    // bounding box it computes, which runs the ends off the corners.)
    final markSize = math.min(120.0, 820 / math.max(watermark.length, 1));

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
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
                      opacity: _watermarkOpacity,
                      child: pw.Center(
                        child: pw.Transform.rotate(
                          angle: math.pi / 4,
                          child: pw.Text(
                            watermark,
                            style: pw.TextStyle(
                              fontSize: markSize,
                              color: _watermark,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
        ),
        // #872 — the letterhead is page furniture, not flow: page one
        // carries it (and reserves the envelope window under it), every
        // later page carries the short strip that says which document
        // this is instead of repeating an address block nobody rereads.
        header: (context) => context.pageNumber == 1
            ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  if (windowOn)
                    // The sender block owns 20 mm → 45 mm, and the flow
                    // resumes at 90 mm: below the 85 × 40 mm aperture
                    // AND below the tolerance band under it.
                    pw.SizedBox(
                      height: addressWindowTop - pageMargin,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: headerWidgets,
                      ),
                    )
                  else
                    ...headerWidgets,
                  if (windowOn)
                    pw.SizedBox(
                        height: addressWindowFlowResume - addressWindowTop),
                ],
              )
            : continuationHeader,
        // #872 — and the footer is pinned to EVERY page, so the terms,
        // the account to pay into and the page number are on whichever
        // sheet the reader is holding.
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            ...footerWidgets,
            // #902/#910 — "1/1" on a one-page letter is noise; the page
            // number earns its place only once there is a second page.
            if (context.pageNumber > 1)
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  '${strings.page} ${context.pageNumber}/${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ),
          ],
        ),
        build: (context) => [
          // #873 — "Facture", its number and the dates, at 90 mm: the
          // first thing under the address field, as the spec requires.
          if (windowOn && report == null) ...[
            pw.Text(numberLine,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _accent)),
            pw.SizedBox(height: 3),
            pw.Text(issuedOnLine,
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.Text(issuedByLine,
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
            if (invoice.replacesNumber.isNotEmpty)
              pw.Text(replacesLine,
                  style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.SizedBox(height: 12),
          ],
          // ── Erroneous banner (0061) ───────────────────────────────
          if (invoice.isVoided && !proforma)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _accent, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Text(strings.voided,
                  style: pw.TextStyle(
                      fontSize: 10,
                      color: _accent,
                      fontWeight: pw.FontWeight.bold)),
            ),
          // #470: the body band replaces billed-to, positions and
          // totals — the detail band of the report.
          ...(report == null
              ? <pw.Widget>[
          // ── Billed to + invoiced month ────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // #869 — the window already shows the recipient; repeating
              // it here would print the address twice.
              if (windowOn)
                pw.Spacer()
              else
                pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: _zebra,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      label(strings.billedTo.toUpperCase()),
                      pw.SizedBox(height: 4),
                      pw.Text(invoice.clientName,
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: _ink)),
                      if (invoice.memberAddress.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(invoice.memberAddress,
                              style: const pw.TextStyle(
                                  fontSize: 9, color: _muted)),
                        ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _hairline),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                    periodLabel.isEmpty ? invoice.title : periodLabel,
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink)),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          // ── Positions ─────────────────────────────────────────────
          pw.Table(
            columnWidths: showVat
                ? const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FlexColumnWidth(0.8),
                    2: pw.FlexColumnWidth(1.2),
                  }
                : const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FlexColumnWidth(1.2),
                  },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _ink),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8),
                    child: pw.Text(strings.description,
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  if (showVat)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 5, horizontal: 8),
                      child: pw.Text(strings.vat,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8),
                    child: pw.Text(strings.total,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              for (final (i, line) in invoice.lines.indexed) ...[
                // #831 — a settlement groups its lines under the source
                // invoice they came from.
                if (line.sourceNumber.isNotEmpty &&
                    (i == 0 ||
                        invoice.lines[i - 1].sourceNumber != line.sourceNumber))
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: _zebra),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        child: pw.Text(line.sourceNumber,
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: _muted,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                      if (showVat) pw.SizedBox(),
                      pw.SizedBox(),
                    ],
                  ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isOdd ? _zebra : PdfColors.white),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 5, horizontal: 8),
                      child: pw.Text(lineText(line),
                          style:
                              const pw.TextStyle(fontSize: 10, color: _ink)),
                    ),
                    if (showVat)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 5, horizontal: 8),
                        // A credit line is money moving, not a supply: it
                        // carries no rate to print.
                        child: pw.Text(
                            line.amountCents > 0
                                ? ratePercent(line.vatPercent)
                                : '',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                      ),
                    amountCell(line.amountCents),
                  ],
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 10),
          // ── Totals: charges / payments / SOLDE ────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 220,
                child: pw.Column(children: [
                  if (showVat) ...[
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(strings.net,
                              style: const pw.TextStyle(
                                  fontSize: 9, color: _muted)),
                          pw.Text(money(invoice.netCents),
                              style: const pw.TextStyle(
                                  fontSize: 9, color: _muted)),
                        ]),
                    for (final total in vatTotals)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                  '${strings.vat} ${ratePercent(total.percent)}',
                                  style: const pw.TextStyle(
                                      fontSize: 9, color: _muted)),
                              pw.Text(money(total.vatCents),
                                  style: const pw.TextStyle(
                                      fontSize: 9, color: _muted)),
                            ]),
                      ),
                    pw.SizedBox(height: 2),
                  ],
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(strings.charges,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                        pw.Text(money(chargesCents),
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                      ]),
                  if (paymentsCents != 0)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Row(
                          mainAxisAlignment:
                              pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(strings.payments,
                                style: const pw.TextStyle(
                                    fontSize: 9, color: _muted)),
                            pw.Text(money(paymentsCents),
                                style: const pw.TextStyle(
                                    fontSize: 9, color: _muted)),
                          ]),
                    ),
                  pw.Container(
                      margin: const pw.EdgeInsets.symmetric(vertical: 5),
                      height: 1.5,
                      color: _accent),
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(strings.total,
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: _ink)),
                        pw.Text(money(invoice.totalCents),
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: _ink)),
                      ]),
                ]),
              ),
            ],
          ),
                ]
              : reportBlockWidgets(report.body, images: reportImages)),
          // ── Annex (0064) ──────────────────────────────────────────
          if (invoice.detailed) ...[
            pw.SizedBox(height: 22),
            pw.Text(strings.annex,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink)),
            pw.Container(
                margin: const pw.EdgeInsets.only(top: 3, bottom: 8),
                height: 1,
                width: 120,
                color: _accent),
            if (invoice.attendance.isNotEmpty) ...[
              label(strings.attendance.toUpperCase()),
              pw.SizedBox(height: 4),
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside:
                      pw.BorderSide(color: _hairline, width: .4),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(2.6),
                },
                children: [
                  for (final row in invoice.attendance)
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(row.startsAt.split('T').first,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _ink)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(
                            '${row.startsAt.split('T').last}–'
                            '${row.endsAt.split('T').last}',
                            style: const pw.TextStyle(
                                fontSize: 9, color: _ink)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(
                            row.status == 'reserved'
                                ? '${row.space} · ${strings.reserved}'
                                : row.space,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                      ),
                    ]),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
            if (invoice.detailLedger.isNotEmpty) ...[
              label(strings.activity.toUpperCase()),
              pw.SizedBox(height: 4),
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside:
                      pw.BorderSide(color: _hairline, width: .4),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.8),
                  2: pw.FlexColumnWidth(1),
                },
                children: [
                  for (final entry in invoice.detailLedger)
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(entry.on,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _ink)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(activityText(entry),
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(money(entry.amountCents),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: entry.amountCents < 0
                                    ? _accent
                                    : _ink)),
                      ),
                    ]),
                ],
              ),
            ],
          ],
          pw.SizedBox(height: 24),
          // ── Digital signature ─────────────────────────────────────
          // A proforma has none: nothing was issued, so there is nothing to
          // fingerprint.
          if (!proforma)
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _hairline)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(strings.signature,
                    style: const pw.TextStyle(fontSize: 7, color: _muted)),
                pw.Text(invoice.signature,
                    style: const pw.TextStyle(fontSize: 7, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  addSheets(
    invoice: invoice,
    proforma: proforma,
    copy: copy,
    report: report,
    dateLabel: dateLabel,
    periodLabel: periodLabel,
    primary: true,
  );
  // The regrouped invoices behind this one, each stamped with where it
  // went. They are documentation, so they carry no report bands and are
  // never a proforma or a copy of anything.
  for (final annex in annexes) {
    addSheets(
      invoice: annex.invoice,
      proforma: false,
      copy: false,
      report: null,
      dateLabel: annex.dateLabel,
      periodLabel: annex.periodLabel,
      watermarkOverride: annex.watermark,
    );
  }
  return doc.save();
}

/// A standalone banded LETTER (#472: the payment reminders) — the
/// report bands on an A4 page with the page footer, but NONE of the
/// invoice's legal chrome: no signature (nothing was issued), no void
/// watermark, no annex.
Future<Uint8List> buildBandedLetterPdf({
  required InvoiceReport report,
  required String pageLabel,
  Map<String, Uint8List> reportImages = const {},
  required String documentTitle,
  required pw.Font baseFont,
  required pw.Font boldFont,
}) {
  final doc = pw.Document(title: documentTitle, producer: _producer);
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
      ),
      footer: (context) => context.pageNumber > 1
          ? pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                '$pageLabel ${context.pageNumber}/${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            )
          : pw.SizedBox(),
      build: (context) => [
        ...reportBlockWidgets(report.header, images: reportImages),
        ...reportBlockWidgets(report.body, images: reportImages),
        if (report.footer.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          ...reportBlockWidgets(report.footer, images: reportImages),
        ],
      ],
    ),
  );
  return doc.save();
}

/// #831 — which stamp a document wears, by priority: a proforma says so
/// first; a source regrouped into a settlement says WHERE it went; a
/// voided one says so; a copy says it is one. One string, or none.
String invoiceWatermark(
  InvoicePdfStrings strings, {
  required bool proforma,
  required bool voided,
  required bool copy,
}) {
  if (proforma) return strings.proforma.toUpperCase();
  if (strings.settledIn.isNotEmpty) return strings.settledIn.toUpperCase();
  if (voided && strings.voidedWatermark.isNotEmpty) {
    return strings.voidedWatermark.toUpperCase();
  }
  return copy ? strings.copy.toUpperCase() : '';
}
