// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — the words of the bank statements: the formats a file is read
// as, where a movement stands, why an invoice is suggested, and why a
// file is refused.
import '../../../l10n/app_localizations.dart';
import '../domain/bank/bank_match.dart';
import '../domain/bank/bank_records.dart';
import '../domain/bank/bank_statement.dart';
import '../domain/bank/csv_statement.dart';

String bankFormatLabel(AppLocalizations l10n, BankFileFormat f) => switch (f) {
  BankFileFormat.camt053 => l10n.bankFormatCamt053,
  BankFileFormat.camt054 => l10n.bankFormatCamt054,
  BankFileFormat.mt940 => l10n.bankFormatMt940,
  BankFileFormat.coda => l10n.bankFormatCoda,
  BankFileFormat.ofx => l10n.bankFormatOfx,
  BankFileFormat.csv => l10n.bankFormatCsv,
};

/// Where [line] stands, in words; an open movement out says it is money
/// out, an open movement in says what it is waiting for.
String bankLineStatusLabel(AppLocalizations l10n, StoredBankLine line) =>
    switch (line.status) {
      BankLineStatus.open =>
        line.isMoneyIn ? l10n.bankLineOpen : l10n.bankLineMoneyOut,
      BankLineStatus.review => l10n.bankLineReview,
      BankLineStatus.duplicate => l10n.bankLineDuplicate,
      BankLineStatus.recorded => l10n.bankLineRecorded,
      BankLineStatus.pending => l10n.bankLinePending(line.invoiceNumber ?? ''),
      BankLineStatus.matched => l10n.bankLineMatched(line.invoiceNumber ?? ''),
      BankLineStatus.reconciled => l10n.bankLineReconciled,
    };

String bankMatchBasisLabel(AppLocalizations l10n, BankMatchBasis b) =>
    switch (b) {
      BankMatchBasis.qrReference => l10n.bankBasisQrReference,
      BankMatchBasis.creditorReference => l10n.bankBasisCreditorReference,
      BankMatchBasis.invoiceNumber => l10n.bankBasisInvoiceNumber,
      BankMatchBasis.amount => l10n.bankBasisAmount,
    };

/// Why a file was refused; nothing of it was imported.
String bankFileRefusal(
  AppLocalizations l10n,
  BankFileException e, {
  required BankFileFormat format,
  required int maxLines,
}) {
  final reason = switch (e.problem) {
    BankFileProblem.tooLarge => l10n.bankRefusedTooLarge,
    BankFileProblem.tooManyLines => l10n.bankRefusedTooManyLines(maxLines),
    BankFileProblem.malformed =>
      l10n.bankRefusedMalformed(bankFormatLabel(l10n, format)),
    BankFileProblem.missingAccount => l10n.bankRefusedMissingAccount,
    BankFileProblem.badAmount => l10n.bankRefusedBadAmount,
    BankFileProblem.badDate => l10n.bankRefusedBadDate,
    BankFileProblem.badCurrency => l10n.bankRefusedBadCurrency,
    BankFileProblem.empty => l10n.bankRefusedEmpty,
  };
  final line = e.line;
  return line == null ? reason : l10n.bankRefusedAtLine(reason, line);
}

/// A day the way [p] writes it, for the person to recognise their file.
String bankCsvDateExample(BankCsvDatePattern p) => switch (p) {
  BankCsvDatePattern.isoDay => '2026-01-31',
  BankCsvDatePattern.dayMonthYearDot => '31.01.2026',
  BankCsvDatePattern.dayMonthYearSlash => '31/01/2026',
  BankCsvDatePattern.monthDayYearSlash => '01/31/2026',
};
