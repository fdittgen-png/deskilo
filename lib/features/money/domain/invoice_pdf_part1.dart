// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoice_pdf.dart';


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

/// The archive PDF of one invoice: the document metadata (and, for a
/// Factur-X, the embedded XML), then the invoice's own sheets, the QR-bill
/// page and the appended annexes.
Future<Uint8List> buildInvoicePdf(InvoicePdfRequest request) async {
  final doc = _pdfDocument(request);
  final theme = pw.ThemeData.withFont(
    base: request.baseFont,
    bold: request.boldFont,
  );
  _InvoiceSheet(
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
    _InvoiceSheet(
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
