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
  return switch (kind.document) {
    ReportDocument.invoice => l10n.invoicePdfTitle,
    ReportDocument.proforma => l10n.invoicePdfProforma,
    ReportDocument.statement => l10n.invoiceTemplateDocStatement,
    ReportDocument.agreement => l10n.reportDocAgreement,
    ReportDocument.payments => l10n.reportDocPayments,
    ReportDocument.customerStatement ||
    ReportDocument.customerStatementPeriod =>
      customerStatementKindLabel(l10n, kind.id),
    ReportDocument.usage => l10n.reportDocUsage,
    ReportDocument.workspace => l10n.reportDocWorkspace,
    ReportDocument.status => l10n.reportDocStatus,
    ReportDocument.biAnalytics => l10n.biPdfTitle,
    ReportDocument.workspaceConfiguration => l10n.workspaceConfigPdfTitle,
    ReportDocument.vatDeclaration => l10n.vatDeclTitle,
    ReportDocument.vat => l10n.reportDocVat,
    ReportDocument.coa => l10n.reportDocCoa,
    ReportDocument.generalLedger ||
    ReportDocument.trialBalance ||
    ReportDocument.journals => _bookLabel(l10n, kind.document),
    ReportDocument.bankReconciliation => l10n.bankReconTitle,
    ReportDocument.badges => l10n.reportDocBadges,
    ReportDocument.spaceCodes => l10n.reportDocSpaceCodes,
    // The documents a business sends in trading.
    ReportDocument.purchaseOrder ||
    ReportDocument.quote ||
    ReportDocument.stockExpiry => _tradingDocumentLabel(l10n, kind.document),
    // A reminder is named by its level above; an id this app does not
    // register keeps the editor usable with the id for a name.
    ReportDocument.reminder || ReportDocument.unknown => kind.id,
  };
}

/// The documents a business sends in trading: a purchase order, a quote; and
/// the stock's expiry report.
String _tradingDocumentLabel(AppLocalizations l10n, ReportDocument document) =>
    switch (document) {
      ReportDocument.purchaseOrder => l10n.reportDocPurchaseOrder,
      ReportDocument.quote => l10n.reportDocQuote,
      _ => l10n.reportDocStockExpiry,
    };

/// #2376 — the books as an accountant reads them.
String _bookLabel(AppLocalizations l10n, ReportDocument document) =>
    switch (document) {
      ReportDocument.generalLedger => l10n.reportDocGeneralLedger,
      ReportDocument.trialBalance => l10n.reportDocTrialBalance,
      _ => l10n.reportDocJournals,
    };
