// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #874 — the app's side of the default letter layouts: the words in
// the reader's language, and the resolution with the owner's design
// (positioned OR banded) in front. The layouts themselves are pure
// Dart in the domain so the CLI prints them too.
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/report_kind.dart';
import '../domain/report_letter_layouts.dart';
import 'report_defaults.dart';
import 'report_kind_labels.dart';

export '../domain/report_letter_layouts.dart'
    show isPersonFacingKind, defaultLetterLayoutXml, resolveLayoutXml, LetterStrings;

LetterStrings letterStringsOf(AppLocalizations? l10n) => LetterStrings(
      creditNote: l10n?.invoicePdfCreditNote ?? 'Credit note',
      replaces: l10n?.invoicePdfReplaces ?? 'Replaces',
      net: l10n?.vatPdfNet ?? 'Net',
      vat: l10n?.vatPdfVat ?? 'VAT',
      vatNumber: l10n?.legalIdentityVatId ?? 'VAT number',
      usage: l10n?.reportDocUsage ?? 'Consumption report',
      status: l10n?.reportDocStatus ?? 'Workspace status',
      records: l10n?.usageReportRecordsHeading ?? 'What was consumed',
      invoice: l10n?.invoicePdfTitle ?? 'Invoice',
      proforma: l10n?.invoicePdfProforma ?? 'Proforma',
      statement: l10n?.invoiceTemplateDocStatement ?? 'Statement',
      agreement: l10n?.reportDocAgreement ?? 'Financial agreement',
      payments: l10n?.reportDocPayments ?? 'Payments report',
      reminder: l10n == null
          ? 'Reminder'
          : l10n.invoiceTemplateDocReminder(0).replaceAll(' 0', '').trim(),
      issuedOn: l10n?.invoicePdfIssuedOn ?? 'Issued on',
      dueOn: l10n?.invoicePdfDueOn ?? 'Due on',
      orderRef: l10n?.invoicePdfPurchaseOrder ?? 'Order',
      serviceRef: l10n?.invoicePdfBuyerReference ?? 'Service',
      description: l10n?.invoicePdfDescription ?? 'Description',
      qty: l10n?.reportColQty ?? 'Qty',
      unitPrice: l10n?.reportColUnitPrice ?? 'Unit price',
      total: l10n?.reportColTotal ?? 'Total',
      paymentsLabel: l10n?.invoicePdfPayments ?? 'Payments',
      balance: l10n?.invoiceBalance ?? 'Balance due',
      regards: l10n?.reportRegards ?? 'Kind regards',
      page: l10n?.invoicePdfPage ?? 'Page',
    );

/// [resolveLayoutXml] with the app's words and the owner's BANDS
/// counted as a design: a kind the owner customised keeps rendering
/// through its bands.
String? resolveLayoutXmlFor({
  required InvoicePdfTemplate template,
  required String kindId,
  required bool letterStandard,
  AppLocalizations? l10n,
  int reminderLevels = 9,
  String countryCode = 'FR',
}) {
  final kind = reportKindById(kindId, reminderLevels: reminderLevels);
  final bandsDesigned = kind != null && bandsOf(template, kind).hasBands;
  final resolved = resolveLayoutXml(
    template: template,
    kindId: kindId,
    letterStandard: letterStandard,
    bandsDesigned: bandsDesigned,
    strings: letterStringsOf(l10n),
    countryCode: countryCode,
  );
  if (resolved == null || template.layoutFor(kindId) != null ||
      kindId == 'invoice' || kindId == 'proforma' || kind == null) {
    return resolved;
  }
  // Use the complete kind-specific content, including reminder wording,
  // pending payments and usage detail, in the standard postal frame.
  final bands = defaultBandsForDoc(kindId, l10n);
  final content = '## ${reportKindLabel(l10n, kind)}\n'
      '{{ member }} · {{ period }}\n'
      '${kindId == 'status' ? '{{ status_from }} → {{ status_to }}' : ''}'
      '\n\n${bands.body}\n\n${bands.footer}';
  final body = content.replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  return resolved.replaceFirst(
    RegExp(r'<body y="90mm">[\s\S]*?</body>'),
    '<body y="90mm"><markup>$body</markup></body>');
}
