// SPDX-License-Identifier: AGPL-3.0-or-later
// A read-only description of one imported statement. This is not proof that
// the bank account's entire period or any provider clearing account is complete.
import 'bank_records.dart';

class BankReconciliationReport {
  BankReconciliationReport({
    required this.statement,
    required List<StoredBankLine> lines,
    this.acceptedSourceLinesMatch = false,
    this.sourceUnavailableOrInaccessible = false,
    this.sourceAssociationUnavailable = false,
    this.requestedFrom,
    this.requestedTo,
  }) : lines = List.unmodifiable(lines);

  final StoredBankStatement statement;
  final List<StoredBankLine> lines;

  /// Explicit user-selected range, distinct from stored movement dates.
  /// Source movements may have been suppressed; their status is not linked.
  final bool sourceAssociationUnavailable;
  final DateTime? requestedFrom;
  final DateTime? requestedTo;

  /// True only when accepted booked movements from the retained original
  /// have been compared with stored rows. The parser may exclude pending
  /// movements; matching these rows does not prove full account coverage.
  final bool acceptedSourceLinesMatch;

  /// A private original could not be found or accessed. This is not proof
  /// of absence; the bank read was re-authorized before returning the report.
  final bool sourceUnavailableOrInaccessible;

  /// A statement arithmetic check, not a comparison to the books. Refuse to
  /// calculate when a line is ambiguous, missing, duplicated or in another
  /// currency; a missing balance is never treated as zero.
  int? get statementDifferenceCents {
    final opening = statement.openingCents;
    final closing = statement.closingCents;
    if (!acceptedSourceLinesMatch ||
        opening == null ||
        closing == null ||
        lines.length != statement.lineCount ||
        lines.map((line) => line.id).toSet().length != lines.length ||
        lines.any(
          (line) =>
              line.currency != statement.currency ||
              line.status == BankLineStatus.review ||
              line.status == BankLineStatus.duplicate,
        )) {
      return null;
    }
    return closing -
        opening -
        lines.fold(0, (sum, line) => sum + line.amountCents);
  }

  /// Only completed bank matching states are called matched; a recorded or
  /// pending payment still needs reconciliation or validation.
  static bool isMatched(StoredBankLine line) =>
      line.status == BankLineStatus.matched ||
      line.status == BankLineStatus.reconciled;

  List<StoredBankLine> get unresolved => [
    for (final line in lines)
      if (!isMatched(line)) line,
  ];
}

/// Labels are supplied by the presentation layer so the same report data can
/// be rendered in the chosen language or archived with explicit wording.
class BankReconciliationWords {
  const BankReconciliationWords({
    required this.account,
    required this.coverageUnavailable,
    required this.recordedDateRange,
    required this.requestedDateRange,
    required this.bookingDate,
    required this.valueDate,
    required this.separateReadsNotice,
    required this.sourceUnavailableOrInaccessible,
    required this.sourceAssociationUnavailable,
    required this.opening,
    required this.closing,
    required this.statementDifference,
    required this.unavailable,
    required this.clearingUnavailable,
    required this.bookDifferenceUnavailable,
    required this.status,
  });
  final String account;
  final String coverageUnavailable;
  final String recordedDateRange;
  final String requestedDateRange;
  final String bookingDate;
  final String valueDate;
  final String separateReadsNotice;
  final String sourceUnavailableOrInaccessible;
  final String sourceAssociationUnavailable;
  final String opening;
  final String closing;
  final String statementDifference;
  final String unavailable;
  final String clearingUnavailable;
  final String bookDifferenceUnavailable;
  final String Function(StoredBankLine) status;
}

/// Designer data for the selected imported statement. The arithmetic check
/// is labelled as such and never claims a reconciliation against the books.
Map<String, Object?> bankReconciliationReportData(
  BankReconciliationReport report, {
  required BankReconciliationWords words,
  required String Function(int, String) money,
  required String Function(DateTime) date,
}) {
  final statement = report.statement;
  String amount(int? value) =>
      value == null ? words.unavailable : money(value, statement.currency);
  Map<String, Object?> row(String label, String detail, String value) => {
    'heading': false,
    'strong': false,
    'label': label,
    'detail': detail,
    'debit': '',
    'credit': '',
    'balance': value,
  };
  return {
    'bank_account': statement.account,
    'bank_currency': statement.currency,
    'book_period':
        '${words.recordedDateRange}: ${date(statement.from)} – ${date(statement.to)}',
    'book_rows': [
      row(words.account, '${statement.account} · ${statement.currency}', ''),
      if (report.requestedFrom != null && report.requestedTo != null)
        row(
          words.requestedDateRange,
          '${date(report.requestedFrom!)} – ${date(report.requestedTo!)}',
          '',
        ),
      row(words.coverageUnavailable, '', words.unavailable),
      row(words.separateReadsNotice, '', ''),
      if (report.sourceUnavailableOrInaccessible)
        row(words.sourceUnavailableOrInaccessible, '', words.unavailable),
      if (report.sourceAssociationUnavailable)
        row(words.sourceAssociationUnavailable, '', words.unavailable),
      row(words.opening, '', amount(statement.openingCents)),
      for (final line in report.lines)
        row(
          '${words.bookingDate}: ${date(line.bookingDate)} · ${words.valueDate}: ${date(line.valueDate)}',
          [
            words.status(line),
            line.counterpartyName,
            line.reference,
            line.remittance,
          ].where((s) => s.isNotEmpty).join(' · '),
          money(line.amountCents, line.currency),
        ),
      row(words.closing, '', amount(statement.closingCents)),
      row(
        words.statementDifference,
        '',
        amount(report.statementDifferenceCents),
      ),
      row(words.bookDifferenceUnavailable, '', words.unavailable),
      row(words.clearingUnavailable, '', words.unavailable),
    ],
  };
}
