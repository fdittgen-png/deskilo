// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/bank/reconciliation_report.dart';
import '../domain/invoice_report.dart';
import 'bank_labels.dart';

BankReconciliationWords bankReconciliationWordsOf(AppLocalizations l10n) =>
    BankReconciliationWords(
      account: l10n.bankReconAccount,
      coverageUnavailable: l10n.bankReconCoverage,
      recordedDateRange: l10n.bankReconObservedDates,
      requestedDateRange: l10n.bankReconRequestedPeriod,
      bookingDate: l10n.bankReconBookingDate,
      valueDate: l10n.bankReconValueDate,
      separateReadsNotice: l10n.bankReconSeparateReads,
      sourceUnavailableOrInaccessible: l10n.bankReconOriginalUnavailable,
      sourceAssociationUnavailable: l10n.bankReconSourceUnassociated,
      opening: l10n.bankReconOpening,
      closing: l10n.bankReconClosing,
      statementDifference: l10n.bankReconArithmeticDifference,
      unavailable: l10n.biDataUnavailable,
      clearingUnavailable: l10n.bankReconClearingUnavailable,
      bookDifferenceUnavailable: l10n.bankReconBooksUnavailable,
      status: (line) => bankLineStatusLabel(l10n, line),
      unmappedLabel: l10n.bankReconUnmappedCount,
      fileArithmeticScope: l10n.bankReconFileArithmeticScope,
      sourceIssueText: (issue) => switch (issue) {
        BankSourceIssue.notRetained => l10n.bankReconSourceNotRetained,
        BankSourceIssue.csvMapping => l10n.bankReconCsvMappingUnavailable,
        BankSourceIssue.unsupportedFormat => l10n.bankReconFormatUnavailable,
        BankSourceIssue.verificationFailed =>
          l10n.bankReconSourceVerificationFailed,
        BankSourceIssue.ambiguousIdentity => l10n.bankReconIdentityAmbiguous,
        BankSourceIssue.readUnavailable => l10n.bankReconReadUnavailable,
      },
    );

/// These limitations belong to the report, not to its editable template.
List<String> bankReconciliationNotices(
  BankReconciliationWords words,
  BankReconciliationReport report,
) => [
  words.coverageUnavailable,
  words.separateReadsNotice,
  if (words.fileArithmeticScope.isNotEmpty) words.fileArithmeticScope,
  words.bookDifferenceUnavailable,
  words.clearingUnavailable,
  if (report.sourceIssue != null) words.sourceIssueText(report.sourceIssue!),
  if (report.unmappedSourceCount != null)
    '${words.unmappedLabel}: ${report.unmappedSourceCount}',
  if (report.sourceUnavailableOrInaccessible)
    words.sourceUnavailableOrInaccessible,
  if (report.sourceAssociationUnavailable) words.sourceAssociationUnavailable,
];

/// Notices are outside editable bands, including the quick preview.
InvoiceReport withBankReconciliationNotices(
  InvoiceReport report,
  List<String> notices,
) => InvoiceReport(
  header: report.header,
  body: [...report.body, for (final notice in notices) ReportText(notice)],
  footer: report.footer,
  continuation: report.continuation,
  numberFirstPage: report.numberFirstPage,
);
