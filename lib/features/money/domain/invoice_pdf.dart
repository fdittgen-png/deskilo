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

part 'invoice_pdf_part1.dart';
part 'invoice_pdf_part2.dart';
part 'invoice_pdf_part3.dart';


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
