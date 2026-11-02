// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/bank/reconciliation_report.dart';
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
    );

/// These limitations belong to the report, not to its editable template.
List<String> bankReconciliationNotices(
  BankReconciliationWords words,
  BankReconciliationReport report,
) => [
  words.coverageUnavailable,
  words.separateReadsNotice,
  words.bookDifferenceUnavailable,
  words.clearingUnavailable,
  if (report.sourceUnavailableOrInaccessible)
    words.sourceUnavailableOrInaccessible,
  if (report.sourceAssociationUnavailable) words.sourceAssociationUnavailable,
];
