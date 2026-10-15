// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/context_l10n.dart';
import '../domain/invoice.dart';
import '../domain/invoice_pdf.dart';
import '../domain/invoice_report.dart';
import 'period_label.dart';

/// The words the invoice PDF prints, resolved in the document's language.
InvoicePdfStrings invoicePdfStringsOf(
  BuildContext context,
  Invoice invoice, {
  required String settledIn,
  required bool development,
}) {
  final l10n = context.l10n;
  final dateFormat = DateFormat.yMMMd(
    Localizations.maybeLocaleOf(context)?.toString(),
  );
  final voidedAt = invoice.voidedAt;
  final voidedLabel = voidedAt == null
      ? ''
      : '${l10n.invoicePdfVoided} '
            '${dateFormat.format(voidedAt)}';
  return InvoicePdfStrings(
    // #508 — a NEGATIVE document is titled as the credit note it is.
    invoiceTitle: invoice.totalCents < 0
        ? (l10n.invoicePdfCreditNote)
        : (l10n.invoicePdfTitle),
    issuedOn: l10n.invoicePdfIssuedOn,
    issuedBy: l10n.invoicePdfIssuedBy,
    billedTo: l10n.invoicePdfBilledTo,
    total: l10n.invoiceBalance,
    signature: l10n.invoicePdfSignature,
    voided: voidedLabel,
    // The archive row's own word for it — one term, everywhere.
    voidedWatermark: l10n.invoiceVoidedChip,
    proforma: l10n.invoicePdfProforma,
    copy: l10n.invoicePdfCopy,
    // #831 — a regrouped source says where it went.
    settledIn: settledIn,
    // #917 — a document printed by a development workspace says so
    // across the page, above every other stamp it could carry.
    development: development ? (l10n.developmentWatermark) : '',
    replaces: l10n.invoicePdfReplaces,
    description: l10n.invoicePdfDescription,
    charges: l10n.invoicePdfCharges,
    payments: l10n.invoicePdfPayments,
    net: l10n.vatPdfNet,
    vat: l10n.vatPdfVat,
    annex: l10n.invoicePdfAnnex,
    attendance: l10n.invoicePdfAttendance,
    activity: l10n.invoicePdfActivity,
    reserved: l10n.invoicePdfReserved,
    page: l10n.invoicePdfPage,
  );
}

/// #837 — every appended invoice keeps its OWN issue date and period;
/// only the stamp is about where it went.
List<InvoiceAnnex> invoiceAnnexesOf(
  BuildContext context,
  Invoice invoice,
  List<Invoice> annexInvoices,
  DateFormat dateFormat,
) => [
  for (final source in annexInvoices)
    (
      invoice: source,
      dateLabel: dateFormat.format(source.issuedAt),
      periodLabel: invoicePeriodLabel(context, source),
      watermark: context.l10n.invoicePdfSettledIn(invoice.number),
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
