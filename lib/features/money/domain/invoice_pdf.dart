// SPDX-License-Identifier: 0BSD
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'invoice.dart';
import 'invoice_report.dart';

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
  final watermark = proforma
      ? strings.proforma.toUpperCase()
      : invoice.isVoided && strings.voidedWatermark.isNotEmpty
          ? strings.voidedWatermark.toUpperCase()
          : copy
              ? strings.copy.toUpperCase()
              : '';
  // Its size follows its LENGTH: 'ERRATA' and 'FEHLERHAFT' must both land
  // inside the sheet. (The package's own Watermark scales to the rotated
  // bounding box it computes, which runs the ends off the corners.)
  final markSize = math.min(120.0, 820 / math.max(watermark.length, 1));

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
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
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          '${strings.page} ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ),
      build: (context) => [
        // #470: the header band replaces the letterhead wholesale.
        ...(report == null
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
            : _reportWidgets(report.header, images: reportImages)),
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
                    pw.Text(invoice.memberName,
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
            for (final (i, line) in invoice.lines.indexed)
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
            : _reportWidgets(report.body, images: reportImages)),
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
        // ── Owner-template footer band (#454/#470): payment terms,
        // legal mentions — under the totals, above the signature.
        if (report != null && report.footer.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          ..._reportWidgets(report.footer, images: reportImages),
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
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          '$pageLabel ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ),
      build: (context) => [
        ..._reportWidgets(report.header, images: reportImages),
        ..._reportWidgets(report.body, images: reportImages),
        if (report.footer.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          ..._reportWidgets(report.footer, images: reportImages),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Report blocks → pdf widgets (#470). Table rows: the first cell takes
/// the width, every further cell is right-aligned — the amounts column
/// convention of the built-in layout.
///
/// Public since #671, so the batch prints (badge sheets, space QR
/// cards) render the SAME markup the report editor edits. A second
/// renderer for those would drift from this one, and the drift would
/// show up as the owner's own wording coming out looking different
/// depending on which button produced the PDF.
List<pw.Widget> reportBlockWidgets(
  List<ReportBlock> blocks, {
  Map<String, Uint8List> images = const {},
}) =>
    _reportWidgets(blocks, images: images);

List<pw.Widget> _reportWidgets(
  List<ReportBlock> blocks, {
  Map<String, Uint8List> images = const {},
}) =>
    [for (final block in blocks) _reportWidget(block, images)];

pw.Widget _reportWidget(
  ReportBlock block,
  Map<String, Uint8List> images,
) =>
    switch (block) {
          ReportHeading(:final text) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(text,
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink)),
            ),
          ReportSubheading(:final text) => pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
              child: pw.Text(text.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 8,
                      color: _muted,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2)),
            ),
          ReportText(:final text) => pw.Text(text,
              style: const pw.TextStyle(fontSize: 10, color: _ink)),
          ReportMuted(:final text) => pw.Text(text,
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
          ReportDivider() => pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 8),
              height: 2,
              color: _accent),
          ReportSpacer() => pw.SizedBox(height: 8),
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
                                    fontSize: 10,
                                    color: _ink,
                                    fontWeight: bold
                                        ? pw.FontWeight.bold
                                        : pw.FontWeight.normal)),
                          )
                        : pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 12),
                            child: pw.Text(cells[i],
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    color: _ink,
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
                        children:
                            _reportWidgets(columns[i], images: images),
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
