// SPDX-License-Identifier: 0BSD
//
// #864 — what each report kind is called, in one place beside the
// registry that says which kinds exist. The editor's chips, the export
// file and any future surface all read it from here, so a kind cannot
// exist without a name or be named twice differently.
import '../../../l10n/app_localizations.dart';
import '../domain/report_kind.dart';

String reportKindLabel(AppLocalizations? l10n, ReportKind kind) {
  if (kind.slot case ReportReminderSlot(:final level)) {
    return l10n?.invoiceTemplateDocReminder(level) ?? 'Reminder $level';
  }
  return switch (kind.id) {
    'invoice' => l10n?.invoiceTemplateDocInvoice ?? 'Invoice',
    'proforma' => l10n?.invoicePdfProforma ?? 'Proforma',
    'statement' => l10n?.invoiceTemplateDocStatement ?? 'Statement',
    'agreement' => l10n?.reportDocAgreement ?? 'Financial agreement',
    'payments' => l10n?.reportDocPayments ?? 'Payments report',
    'workspace' => l10n?.reportDocWorkspace ?? 'Workspace report',
    'coa' => l10n?.reportDocCoa ?? 'Chart of accounts',
    'badges' => l10n?.reportDocBadges ?? 'Member badges',
    'space_codes' => l10n?.reportDocSpaceCodes ?? 'Space QR cards',
    // A kind in the registry with no label here is a bug the lint test
    // catches; falling back to the id keeps the editor usable meanwhile.
    _ => kind.id,
  };
}
