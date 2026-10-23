// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The data report's words and formats in the reader's language: its own
// keys first, then the workbook's sheet, column and value names, so a
// column reads the same in the PDF as in the Excel file.
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_data_report_pdf.dart';
import 'workspace_configuration_report_strings.dart';

/// The sheet whose name titles a table of the report.
const _tableSheets = {'balances': 'ledger', 'purchases': 'purchase_documents'};

/// [l10n]'s lookup [select], falling back to [fallback] when it has no
/// word of its own for [key] (an ICU select answers the key itself).
String Function(String) _first(
  String Function(String) select,
  String Function(String) fallback,
) => (key) {
  final word = select(key);
  return word == key ? fallback(key) : word;
};

String _purchaseWord(AppLocalizations l10n, String key) => switch (key) {
  'bill' => l10n.purchasesKindBill,
  'credit_note' => l10n.purchasesKindCreditNote,
  'member_receipt' => l10n.purchasesKindReceipt,
  'draft' => l10n.purchasesStateDraft,
  'pending' => l10n.purchasesStatePending,
  'approved' => l10n.purchasesStateApproved,
  'rejected' => l10n.purchasesStateRejected,
  'cancelled' => l10n.purchasesStateCancelled,
  'archived' => l10n.dataReportArchived,
  _ => l10n.exportValueName(key),
};

/// The report's strings in [l10n], amounts in [currency].
WorkspaceDataReportStrings workspaceDataReportStrings(
  AppLocalizations l10n, {
  required String currency,
  String? locale,
}) {
  final money = moneyFormat(currency, locale: locale);
  final numbers = NumberFormat.decimalPattern(locale)
    ..maximumFractionDigits = 1;
  return WorkspaceDataReportStrings(
    title: l10n.dataReportTitle,
    contents: l10n.dataReportContents,
    workspace: l10n.exportAboutWorkspace,
    period: l10n.exportColumnName('period'),
    generatedOn: l10n.exportAboutGeneratedOn,
    timeZone: l10n.workspaceTimezoneLabel,
    currency: l10n.workspaceCurrencyLabel,
    total: l10n.exportColumnName('total'),
    none: l10n.dataReportNone,
    yes: l10n.dataReportYes,
    no: l10n.dataReportNo,
    pageLabel: l10n.invoicePdfPage,
    part: (part) => l10n.dataReportPart(part.name),
    table: (key) => l10n.exportSheetName(_tableSheets[key] ?? key),
    column: _first(l10n.dataReportColumn, l10n.exportColumnName),
    word: (key) => _purchaseWord(l10n, key),
    role: (key) => switch (key) {
      'owner' => l10n.memberRoleOwner,
      'admin' => l10n.memberRoleAdmin,
      'kiosk' => l10n.exportColumnName('kiosk'),
      _ => l10n.memberRoleMember,
    },
    wholeLevel: workspaceConfigurationStrings(l10n).levelBookable,
    money: money.formatMinor,
    day: DateFormat.yMMMd(locale).format,
    month: DateFormat.yMMMM(locale).format,
    number: numbers.format,
  );
}
