// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf.dart';
import '../domain/invoice_report.dart';
import 'period_label.dart';

/// The words the invoice PDF prints, resolved in the document's language:
/// [l10n] and [localeName] when the caller names one (#3673, the
/// customer's), else the interface's.
InvoicePdfStrings invoicePdfStringsOf(
  BuildContext context,
  Invoice invoice, {
  required String settledIn,
  required bool development,
  AppLocalizations? l10n,
  String? localeName,
}) {
  final words = l10n ?? context.l10n;
  final dateFormat = DateFormat.yMMMd(
    localeName ?? Localizations.maybeLocaleOf(context)?.toString(),
  );
  final voidedAt = invoice.voidedAt;
  final voidedLabel = voidedAt == null
      ? ''
      : words.invoicePdfVoidedOn(dateFormat.format(voidedAt));
  return InvoicePdfStrings(
    // #508 — a NEGATIVE document is titled as the credit note it is.
    invoiceTitle: invoice.totalCents < 0
        ? (words.invoicePdfCreditNote)
        : (words.invoicePdfTitle),
    issuedOn: words.invoicePdfIssuedOn,
    issuedBy: words.invoicePdfIssuedBy,
    billedTo: words.invoicePdfBilledTo,
    total: words.invoiceBalance,
    signature: words.invoicePdfSignature,
    voided: voidedLabel,
    // The archive row's own word for it — one term, everywhere.
    voidedWatermark: words.invoiceVoidedChip,
    proforma: words.invoicePdfProforma,
    copy: words.invoicePdfCopy,
    // #831 — a regrouped source says where it went.
    settledIn: settledIn,
    // #917 — a document printed by a development workspace says so
    // across the page, above every other stamp it could carry.
    development: development ? (words.developmentWatermark) : '',
    replaces: words.invoicePdfReplaces,
    description: words.invoicePdfDescription,
    charges: words.invoicePdfCharges,
    payments: words.invoicePdfPayments,
    net: words.vatPdfNet,
    vat: words.vatPdfVat,
    subtotal: words.invoicePdfSubtotal,
    exemptCertificate: words.invoicePdfExemptCertificate,
    annex: words.invoicePdfAnnex,
    attendance: words.invoicePdfAttendance,
    activity: words.invoicePdfActivity,
    reserved: words.invoicePdfReserved,
    page: words.invoicePdfPage,
    titleNumbered: invoice.totalCents < 0
        ? words.billCreditNoteCard('{value}')
        : words.billInvoiceCard('{value}'),
    issuedOnDated: words.invoicePdfIssuedOnDate('{value}'),
    issuedByNamed: words.invoicePdfIssuedByName('{value}'),
    replacesNumbered: words.invoicePdfReplacesNumber('{value}'),
    vatRated: words.vatPdfVatRate('{value}'),
  );
}

/// #837 — every appended invoice keeps its OWN issue date and period;
/// only the stamp is about where it went.
List<InvoiceAnnex> invoiceAnnexesOf(
  BuildContext context,
  Invoice invoice,
  List<Invoice> annexInvoices,
  DateFormat dateFormat, {
  AppLocalizations? l10n,
  String? localeName,
}) => [
  for (final source in annexInvoices)
    (
      invoice: source,
      dateLabel: dateFormat.format(source.issuedAt),
      periodLabel: localeName == null
          ? invoicePeriodLabel(context, source)
          : invoicePeriodLabelOf(localeName, source),
      watermark: (l10n ?? context.l10n).invoicePdfSettledIn(invoice.number),
    ),
];

/// #488 — the pictures the report bands name, resolved by the caller.
Future<Map<String, Uint8List>> reportImagesOf(
  InvoiceReport? report,
  Future<Uint8List?> Function(String name)? reportImage,
) async {
  final reportImages = <String, Uint8List>{};
  if (report != null && reportImage != null) {
    for (final name in reportImageRefs(report)) {
      final imageBytes = await reportImage(name);
      if (imageBytes != null) reportImages[name] = imageBytes;
    }
  }
  return reportImages;
}
