// SPDX-License-Identifier: 0BSD
//
// #874 — the app's side of the default letter layouts: the words in
// the reader's language, and the resolution with the owner's design
// (positioned OR banded) in front. The layouts themselves are pure
// Dart in the domain so the CLI prints them too.
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/report_kind.dart';
import '../domain/report_letter_layouts.dart';

export '../domain/report_letter_layouts.dart'
    show isPersonFacingKind, defaultLetterLayoutXml, resolveLayoutXml, LetterStrings;

LetterStrings letterStringsOf(AppLocalizations? l10n) => LetterStrings(
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
}) {
  final kind = reportKindById(kindId, reminderLevels: reminderLevels);
  final bandsDesigned = kind != null && bandsOf(template, kind).hasBands;
  return resolveLayoutXml(
    template: template,
    kindId: kindId,
    letterStandard: letterStandard,
    bandsDesigned: bandsDesigned,
    strings: letterStringsOf(l10n),
  );
}
