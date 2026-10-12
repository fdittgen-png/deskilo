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
