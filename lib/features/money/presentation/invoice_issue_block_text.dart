// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_issue_readiness.dart';

/// The title the issue form's banner gives [block]: invoicing off, a VAT
/// treatment issued outside the app, or the essentials still to complete.
String invoiceIssueBlockTitle(AppLocalizations l10n, InvoiceIssueBlock block) =>
    switch (block) {
      InvoiceIssueBlock.disabled => l10n.invoiceIssuingUnavailable,
      InvoiceIssueBlock.external => l10n.invoiceExternalIssuingTitle,
      InvoiceIssueBlock.missing ||
      InvoiceIssueBlock.none => l10n.invoiceMissingTitle,
    };
