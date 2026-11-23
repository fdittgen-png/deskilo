// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #864 — what each report kind is called, in one place beside the
// registry that says which kinds exist. The editor's chips, the export
// file and any future surface all read it from here, so a kind cannot
// exist without a name or be named twice differently.
import '../../../l10n/app_localizations.dart';
import '../domain/report_kind.dart';
import 'report_defaults_customer_statement.dart';

String reportKindLabel(AppLocalizations l10n, ReportKind kind) {
  if (kind.slot case ReportReminderSlot(:final level)) {
    return l10n.invoiceTemplateDocReminder(level);
  }
  return switch (kind.id) {
    'invoice' => l10n.invoicePdfTitle,
    'proforma' => l10n.invoicePdfProforma,
    'statement' => l10n.invoiceTemplateDocStatement,
    'agreement' => l10n.reportDocAgreement,
    'payments' => l10n.reportDocPayments,
    'customer_statement' || 'customer_statement_period' =>
      customerStatementKindLabel(l10n, kind.id),
    'usage' => l10n.reportDocUsage,
    'workspace' => l10n.reportDocWorkspace,
    'status' => l10n.reportDocStatus,
    'bi_analytics' => l10n.biPdfTitle,
    'workspace_configuration' => l10n.workspaceConfigPdfTitle,
    'vat_declaration' => l10n.vatDeclTitle,
    'vat' => l10n.reportDocVat,
    'coa' => l10n.reportDocCoa,
    'general_ledger' => l10n.reportDocGeneralLedger,
    'trial_balance' => l10n.reportDocTrialBalance,
    'journals' => l10n.reportDocJournals,
    'bank_reconciliation' => l10n.bankReconTitle,
    'badges' => l10n.reportDocBadges,
    'space_codes' => l10n.reportDocSpaceCodes,
    // A kind in the registry with no label here is a bug the lint test
    // catches; falling back to the id keeps the editor usable meanwhile.
    _ => _tradingDocumentLabel(l10n, kind.id) ?? kind.id,
  };
}

/// The documents a business sends in trading: a purchase order, a quote; and the stock's expiry report.
String? _tradingDocumentLabel(AppLocalizations l10n, String id) => switch (id) {
  'purchase_order' => l10n.reportDocPurchaseOrder,
  'quote' => l10n.reportDocQuote,
  'stock_expiry' => l10n.reportDocStockExpiry,
  _ => null,
};
