// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Statement arithmetic and matching status stay separate and unknown facts never become zero.
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/bank/reconciliation_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime.utc(2026);
  StoredBankStatement statement({
    int? opening = 10000,
    int? closing = 13000,
    int count = 2,
  }) => StoredBankStatement(
    id: 's',
    format: BankFileFormat.camt053,
    account: 'test',
    currency: 'EUR',
    from: day,
    to: day,
    lineCount: count,
    openCount: 0,
    openingCents: opening,
    closingCents: closing,
  );
  StoredBankLine line(
    String id,
    int amount,
    BankLineStatus status, {
    String currency = 'EUR',
  }) => StoredBankLine(
    id: id,
    position: 1,
    bookingDate: day,
    valueDate: day,
    amountCents: amount,
    currency: currency,
    status: status,
    remittance: id,
  );

  test('an added unmatched line is not itself an arithmetic difference', () {
    final matched = line('invoice', 5000, BankLineStatus.matched);
    final baseline = BankReconciliationReport(
      statement: statement(count: 1, closing: 15000),
      acceptedSourceLinesMatch: true,
      lines: [matched],
    );
    expect(baseline.statementDifferenceCents, 0);
    expect(baseline.unresolved, isEmpty);
    // The second source records its own closing balance after this movement;
    // it is synthetic fixture evidence, not a derived real bank balance.
    final after = BankReconciliationReport(
      statement: statement(),
      acceptedSourceLinesMatch: true,
      lines: [matched, line('named unmatched', -2000, BankLineStatus.open)],
    );
    expect(after.statementDifferenceCents, 0);
    expect(after.unresolved.single.remittance, 'named unmatched');
  });

  test(
    'report preserves both dates, names the line and does not invent clearing',
    () {
      final movement = StoredBankLine(
        id: 'named',
        position: 1,
        bookingDate: day,
        valueDate: DateTime.utc(2026, 1, 2),
        amountCents: 3000,
        currency: 'EUR',
        status: BankLineStatus.open,
        remittance: 'Named unmatched',
      );
      final report = BankReconciliationReport(
        statement: statement(count: 1),
        acceptedSourceLinesMatch: true,
        requestedFrom: DateTime.utc(2026),
        requestedTo: DateTime.utc(2026, 12, 31),
        lines: [movement],
      );
      final data = bankReconciliationReportData(
        report,
        words: BankReconciliationWords(
          account: 'Account',
          coverageUnavailable: 'Coverage not verified',
          recordedDateRange: 'Stored movement dates',
          requestedDateRange: 'Requested period',
          bookingDate: 'Booking',
          valueDate: 'Value',
          separateReadsNotice: 'Reads are not a snapshot',
          sourceUnavailableOrInaccessible:
              'Original unavailable or inaccessible',
          canonicalMovement: 'Previously retained movement',
          opening: 'Opening',
          closing: 'Closing',
          statementDifference: 'Statement arithmetic difference',
          unavailable: 'Unavailable',
          clearingUnavailable: 'Provider clearing',
          bookDifferenceUnavailable: 'Difference against books',
          status: (line) => line.status.name,
        ),
        money: (amount, currency) => '$amount $currency',
        date: (value) => value.toIso8601String().substring(0, 10),
      );
      final rows = data['book_rows'] as List<Map<String, Object?>>;
      expect(
        data['book_period'],
        'Stored movement dates: 2026-01-01 – 2026-01-01',
      );
      expect(
        rows.singleWhere((row) => row['label'] == 'Requested period')['detail'],
        '2026-01-01 – 2026-12-31',
      );
      expect(
        rows.singleWhere(
          (row) => row['label'] == 'Booking: 2026-01-01 · Value: 2026-01-02',
        )['detail'],
        contains('Named unmatched'),
      );
      expect(
        rows.singleWhere(
          (row) => row['label'] == 'Statement arithmetic difference',
        )['balance'],
        '0 EUR',
      );
      expect(
        rows.singleWhere(
          (row) => row['label'] == 'Difference against books',
        )['balance'],
        'Unavailable',
      );
      expect(rows.last['balance'], 'Unavailable');
    },
  );

  test('source access ambiguity is visible in the report', () {
    final report = BankReconciliationReport(
      statement: statement(),
      lines: [],
      sourceUnavailableOrInaccessible: true,
    );
    final data = bankReconciliationReportData(
      report,
      words: BankReconciliationWords(
        account: 'Account',
        coverageUnavailable: 'Coverage unknown',
        recordedDateRange: 'Stored movement dates',
        requestedDateRange: 'Requested period',
        bookingDate: 'Booking',
        valueDate: 'Value',
        separateReadsNotice: 'Reads are not a snapshot',
        sourceUnavailableOrInaccessible: 'Original unavailable or inaccessible',
        canonicalMovement: 'Previously retained movement',
        opening: 'Opening',
        closing: 'Closing',
        statementDifference: 'Statement arithmetic difference',
        unavailable: 'Unavailable',
        clearingUnavailable: 'Provider clearing',
        bookDifferenceUnavailable: 'Difference against books',
        status: (line) => line.status.name,
      ),
      money: (amount, currency) => '$amount $currency',
      date: (value) => value.toIso8601String(),
    );
    final rows = data['book_rows'] as List<Map<String, Object?>>;
    expect(
      rows.any(
        (row) =>
            row['label'] == 'Original unavailable or inaccessible' &&
            row['balance'] == 'Unavailable',
      ),
      isTrue,
    );
    expect(report.statementDifferenceCents, isNull);
  });

  test('stored row count alone does not establish source completeness', () {
    final report = BankReconciliationReport(
      statement: statement(),
      lines: [
        line('a', 5000, BankLineStatus.matched),
        line('b', -2000, BankLineStatus.open),
      ],
    );
    expect(report.statementDifferenceCents, isNull);
  });

  test('missing, incomplete, ambiguous or mixed currency is unavailable', () {
    final a = line('a', 5000, BankLineStatus.matched);
    final b = line('b', -2000, BankLineStatus.open);
    expect(
      BankReconciliationReport(
        acceptedSourceLinesMatch: true,
        statement: statement(opening: null),
        lines: [a, b],
      ).statementDifferenceCents,
      isNull,
    );
    expect(
      BankReconciliationReport(
        acceptedSourceLinesMatch: true,
        statement: statement(),
        lines: [a],
      ).statementDifferenceCents,
      isNull,
    );
    expect(
      BankReconciliationReport(
        acceptedSourceLinesMatch: true,
        statement: statement(),
        lines: [a, a],
      ).statementDifferenceCents,
      isNull,
    );
    expect(
      BankReconciliationReport(
        acceptedSourceLinesMatch: true,
        statement: statement(),
        lines: [a, line('b', -2000, BankLineStatus.review)],
      ).statementDifferenceCents,
      isNull,
    );
    expect(
      BankReconciliationReport(
        acceptedSourceLinesMatch: true,
        statement: statement(),
        lines: [
          a,
          line('b', -2000, BankLineStatus.open, currency: 'USD'),
        ],
      ).statementDifferenceCents,
      isNull,
    );
  });
}
