// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/vat_declaration_report.dart';

ReportBands vatDeclarationBandsOf(AppLocalizations l10n) =>
    defaultVatDeclarationBands(
      VatDeclarationPdfStrings(
        title: l10n.vatDeclTitle,
        period: l10n.vatDeclPeriod,
        vatIdLabel: l10n.vatDeclVatId,
        colRate: l10n.vatDeclRate,
        colNet: l10n.vatDeclNet,
        colVat: l10n.vatDeclVat,
        colInvoices: l10n.vatDeclInvoices,
        totals: l10n.vatDeclTotals,
        boxesTitle: l10n.vatDeclBoxes,
        colBox: l10n.vatDeclBox,
        statusLabel: l10n.vatDeclStatus,
      ),
    );
