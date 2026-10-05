// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/vat_declaration_report.dart';

ReportBands vatDeclarationBandsOf(AppLocalizations? l10n) =>
    defaultVatDeclarationBands(
      VatDeclarationPdfStrings(
        title: l10n?.vatDeclTitle ?? 'VAT declaration',
        period: l10n?.vatDeclPeriod ?? 'Period',
        vatIdLabel: l10n?.vatDeclVatId ?? 'VAT ID',
        colRate: l10n?.vatDeclRate ?? 'Rate',
        colNet: l10n?.vatDeclNet ?? 'Net base',
        colVat: l10n?.vatDeclVat ?? 'VAT',
        colInvoices: l10n?.vatDeclInvoices ?? 'Invoices',
        totals: l10n?.vatDeclTotals ?? 'Totals',
        boxesTitle: l10n?.vatDeclBoxes ?? 'Official form lines',
        colBox: l10n?.vatDeclBox ?? 'Box',
        statusLabel: l10n?.vatDeclStatus ?? 'Status',
      ),
    );
