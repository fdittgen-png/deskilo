// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'address_window.dart';
import 'invoice.dart';
import 'invoice_report.dart';
import 'report_block_widgets.dart';
import 'report_flow_page.dart';
import 'report_page_footer.dart';
import 'vat_rate.dart';

part 'invoice_pdf_part1.dart';
part 'invoice_pdf_part2.dart';
part 'invoice_pdf_part3.dart';


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

  /// Annex section titles (0064).
  final String annex;
  final String attendance;
  final String activity;

  /// Suffix on an attendance row that was booked but not attended.
  final String reserved;

  /// Footer page label ('Page').
  final String page;
}
