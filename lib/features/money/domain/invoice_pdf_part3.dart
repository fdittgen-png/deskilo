// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoice_pdf.dart';


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
