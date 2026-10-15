// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #874 — the app's side of the default letter layouts: the words in
// the reader's language, and the resolution with the owner's design
// (positioned OR banded) in front. The layouts themselves are pure
// Dart in the domain so the CLI prints them too.
import '../../../core/l10n/context_l10n.dart';
import '../../../core/vat/tax_reference_active.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/report_kind.dart';
import '../domain/report_letter_layouts.dart';
import 'report_defaults.dart';
import 'report_kind_labels.dart';

export '../domain/report_letter_layouts.dart'
    show LetterStrings, defaultLetterLayoutXml, isPersonFacingKind, resolveLayoutXml;

LetterStrings _letterStringsOf(AppLocalizations l10n, {bool salesTax = false}) => LetterStrings(
      creditNote: l10n.invoicePdfCreditNote,
      replaces: l10n.invoicePdfReplaces,
      // #2362 -- a sales-tax invoice speaks of a subtotal and a sales tax.
      net: salesTax ? l10n.invoicePdfSubtotal : l10n.vatPdfNet,
      vat: salesTax ? l10n.invoicePdfSalesTax : l10n.vatPdfVat,
      vatNumber: l10n.legalIdentityVatId,
      usage: l10n.reportDocUsage,
      status: l10n.reportDocStatus,
      records: l10n.usageReportRecordsHeading,
      invoice: l10n.invoicePdfTitle,
      proforma: l10n.invoicePdfProforma,
      statement: l10n.invoiceTemplateDocStatement,
      agreement: l10n.reportDocAgreement,
      payments: l10n.reportDocPayments,
      reminder: l10n.invoiceTemplateDocReminder(0).replaceAll(' 0', '').trim(),
      issuedOn: l10n.invoicePdfIssuedOn,
      dueOn: l10n.invoicePdfDueOn,
      orderRef: l10n.invoicePdfPurchaseOrder,
      serviceRef: l10n.invoicePdfBuyerReference,
      description: l10n.invoicePdfDescription,
      qty: l10n.reportColQty,
      unitPrice: l10n.reportColUnitPrice,
      total: l10n.reportColTotal,
      paymentsLabel: l10n.invoicePdfPayments,
      balance: l10n.invoiceBalance,
      regards: l10n.reportRegards,
      page: l10n.invoicePdfPage,
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
    // #2362 -- a seller whose country's gate says sales tax speaks of a
    // subtotal and a sales tax, never of VAT.
    strings: _letterStringsOf(l10n ?? englishL10n,
        salesTax: ActiveTaxReference.isInstalled &&
            (ActiveTaxReference.current.gateOf(countryCode)?.salesTaxMode ??
                false)),
    countryCode: countryCode,
  );
  if (resolved == null || template.layoutFor(kindId) != null ||
      kindId == 'invoice' || kindId == 'proforma' || kind == null) {
    return resolved;
  }
  // Use the complete kind-specific content, including reminder wording,
  // pending payments and usage detail, in the standard postal frame.
  final bands = defaultBandsForDoc(kindId, l10n ?? englishL10n);
  final content = '## ${reportKindLabel(l10n ?? englishL10n, kind)}\n'
      '{{ member }} · {{ period }}\n'
      '${kindId == 'status' ? '{{ status_from }} → {{ status_to }}' : ''}'
      '\n\n${bands.body}\n\n${bands.footer}';
  final body = content.replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  return resolved.replaceFirst(
    RegExp(r'<body y="90mm">[\s\S]*?</body>'),
    '<body y="90mm"><markup>$body</markup></body>');
}
