// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'address_window.dart';
import 'invoice.dart';
import 'invoice_pdf_sheet.dart';
import 'invoice_pdf_style.dart';
import 'invoice_report.dart';
import 'report_block_widgets.dart';
import 'report_flow_page.dart';



/// Everything [buildInvoicePdf] renders from. One object instead of a long
/// argument list: a new document field is added here and in one section
/// of the sheet.
class InvoicePdfRequest {
  const InvoicePdfRequest({
    required this.invoice,
    required this.strings,
    this.reportImages = const {},
    required this.money,
    required this.lineText,
    required this.activityText,
    required this.dateLabel,
    required this.baseFont,
    required this.boldFont,
    this.periodLabel = '',
    this.proforma = false,
    this.copy = false,
    this.facturXml = '',
    this.report,
    this.colorProfile,
    this.annexes = const [],
    this.addressWindow = AddressWindow.off,
    this.qrBillPage,
  });

  final Invoice invoice;
  final InvoicePdfStrings strings;
  final Map<String, Uint8List> reportImages;
  final String Function(int cents) money;
  final String Function(InvoiceLine line) lineText;
  final String Function(InvoiceDetailEntry entry) activityText;
  final String dateLabel;
  final pw.Font baseFont;
  final pw.Font boldFont;

  /// What the invoice COVERS, in words ('July 2026'). The stored
  /// [Invoice.title] is the raw period ('2026-07'), which no reader should
  /// have to decode; empty falls back to it (legacy 0060 free-form titles).
  final String periodLabel;

  /// Renders the SAME figures as a proforma: a quote for a month, not a
  /// document of record. It carries no signature (there is nothing to
  /// certify), says PROFORMA where an invoice says its number, and wears
  /// the same diagonal watermark so the two can never be confused on a
  /// desk. An issued invoice can also be re-rendered this way — as a
  /// payment request that does not pass for the original.
  final bool proforma;

  /// Stamps the render as a duplicate: the issuer holds the original, the
  /// member re-renders it on demand. Ignored on a proforma (which is not a
  /// copy of anything) and on an erroneous invoice (whose own stamp wins).
  final bool copy;

  /// FACTUR-X: the EN 16931 invoice as CII, embedded in the PDF itself.
  /// Turns the document into PDF/A-3 (the format's requirement) carrying
  /// `factur-x.xml` — one file a human reads and a machine parses, which
  /// is what French and German small businesses actually exchange.
  /// Requires [colorProfile] (PDF/A demands an output intent).
  final String facturXml;

  /// Owner report bands (#454/#470), already rendered by
  /// `renderReportBands`. Null = the built-in layout. PDF only — the
  /// XML never carries them; the void banner/watermark, signature,
  /// annex and page numbers stay non-templated regardless.
  final InvoiceReport? report;
  final Uint8List? colorProfile;

  /// #837 — invoices appended AFTER this one as reference, in order.
  /// A settlement uses it to carry the invoices it regrouped, each
  /// stamped with the number that now owes their balance.
  final List<InvoiceAnnex> annexes;

  /// #869 — where the recipient sits so it shows through a window
  /// envelope. Resolved by the caller from the template and the seller's
  /// country, because only the caller knows both.
  final AddressWindow addressWindow;

  /// #2360 — the Swiss QR-bill, on a page of its own after the invoice
  /// (before any annex); null for every other document.
  final pw.Page? qrBillPage;
}

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
    this.development = '',
    required this.replaces,
    required this.description,
    required this.charges,
    required this.payments,
    this.net = '',
    this.vat = '',
    this.subtotal = '',
    this.exemptCertificate = '',
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

  /// #917 — the word a document printed by a DEVELOPMENT workspace
  /// carries across the page. '' from a production workspace, which is
  /// what makes its absence meaningful.
  final String development;

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

  /// #2362 -- a sales-tax invoice: the caption of the net subtotal and the
  /// words before the certificate that exempted lines. '' falls back to [net].
  final String subtotal;
  final String exemptCertificate;

  /// Annex section titles (0064).
  final String annex;
  final String attendance;
  final String activity;

  /// Suffix on an attendance row that was booked but not attended.
  final String reserved;

  /// Footer page label ('Page').
  final String page;
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
  /// #917 — 'DEVELOPMENT' when the workspace is not a real one. Every
  /// report the app prints goes through here or through the positioned
  /// engine, and both carry it: a statement, an agreement, a VAT report
  /// or a reminder from a rehearsal space must be as unmistakable as
  /// the invoices are.
  String watermark = '',
}) {
  final doc = pw.Document(title: documentTitle, producer: _producer)
    ..addPage(
    reportFlowPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
        buildForeground: watermarkForeground(watermark),
      ),
      documentTitle: documentTitle,
      pageLabel: pageLabel,
      firstHeader: (context) => reportBlockWidgets(report.header, images: reportImages),
      continuation: report.continuation.isEmpty ? null :
          (context) => reportBlockWidgets(report.continuation, images: reportImages),
      footer: (context) => reportBlockWidgets(report.footer, images: reportImages),
      body: (context) => reportBlockWidgets(report.body, images: reportImages),
      numberFirstPage: report.numberFirstPage,
    ),
  );
  return doc.save();
}

/// #917 — the diagonal mark, painted the same way on EVERY document
/// this app produces. Its size follows the word's LENGTH so a long one
/// ('DÉVELOPPEMENT', 'FEHLERHAFT') still lands inside the sheet.
pw.Widget Function(pw.Context)? watermarkForeground(String watermark) {
  if (watermark.isEmpty) return null;
  final markSize = math.min(120.0, 820 / math.max(watermark.length, 1));
  return (context) => pw.FullPage(
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
      );
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
  // #917 — "this is not a real document" outranks every other thing the
  // page could say about itself. A rehearsal invoice that is ALSO a
  // proforma, a copy or an erratum is, first and last, not real; the
  // banner and the header still carry the finer state, and the one word
  // running across the sheet carries the one that matters at a glance.
  if (strings.development.isNotEmpty) {
    return strings.development.toUpperCase();
  }
  if (proforma) return strings.proforma.toUpperCase();
  if (strings.settledIn.isNotEmpty) return strings.settledIn.toUpperCase();
  if (voided && strings.voidedWatermark.isNotEmpty) {
    return strings.voidedWatermark.toUpperCase();
  }
  return copy ? strings.copy.toUpperCase() : '';
}

/// Named in the PDF metadata — PDF/A wants a producer, and a reader
/// wondering where a file came from deserves an answer.
const String _producer = 'DesKilo';

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

/// The archive PDF of one invoice: the document metadata (and, for a
/// Factur-X, the embedded XML), then the invoice's own sheets, the QR-bill
/// page and the appended annexes.
Future<Uint8List> buildInvoicePdf(InvoicePdfRequest request) async {
  final doc = _pdfDocument(request);
  final theme = pw.ThemeData.withFont(
    base: request.baseFont,
    bold: request.boldFont,
  );
  InvoiceSheet(
    request,
    theme,
    invoice: request.invoice,
    proforma: request.proforma,
    copy: request.copy,
    report: request.report,
    dateLabel: request.dateLabel,
    periodLabel: request.periodLabel,
    primary: true,
  ).addTo(doc);
  if (request.qrBillPage != null) doc.addPage(request.qrBillPage!);
  // The regrouped invoices behind this one, each stamped with where it
  // went. They are documentation, so they carry no report bands and are
  // never a proforma or a copy of anything.
  for (final annex in request.annexes) {
    InvoiceSheet(
      request,
      theme,
      invoice: annex.invoice,
      proforma: false,
      copy: false,
      report: null,
      dateLabel: annex.dateLabel,
      periodLabel: annex.periodLabel,
      watermarkOverride: annex.watermark,
    ).addTo(doc);
  }
  return doc.save();
}

/// The document with its metadata; a Factur-X also carries the colour
/// profile and the XML (PDF/A-3).
pw.Document _pdfDocument(InvoicePdfRequest request) {
  final invoice = request.invoice;
  final strings = request.strings;
  final periodLabel = request.periodLabel;
  final colorProfile = request.colorProfile;
  final hybrid = request.facturXml.isNotEmpty && colorProfile != null;
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
        data: request.facturXml,
      ),
    ]);
  }
  return doc;
}
