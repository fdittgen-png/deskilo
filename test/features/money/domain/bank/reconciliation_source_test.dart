// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Source verification rejects omitted movements, ambiguous source scope and currency mismatch.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:deskilo/features/money/domain/bank/bank_file.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/bank/reconciliation_report.dart';
import 'package:deskilo/features/money/domain/bank/reconciliation_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retained source verifies all stored lines, not just stored count', () {
    final bytes = File(
      'test/features/money/fixtures/bank/camt053_statement.xml',
    ).readAsBytesSync();
    const limits = BankFileLimits(maxBytes: 1000000, maxLines: 1000);
    final parsed = parseBankFile(
      bytes,
      format: BankFileFormat.camt053,
      limits: limits,
    );
    final lines = <StoredBankLine>[
      for (var i = 0; i < parsed.lines.length; i++)
        StoredBankLine(
          id: '$i',
          position: i + 1,
          bookingDate: parsed.lines[i].bookingDate,
          valueDate: parsed.lines[i].valueDate,
          amountCents: parsed.lines[i].amountCents,
          currency: parsed.lines[i].currency,
          status: BankLineStatus.open,
          transactionId: parsed.lines[i].transactionId,
          counterpartyName: parsed.lines[i].counterpartyName,
          counterpartyIban: parsed.lines[i].counterpartyIban,
          reference: parsed.lines[i].reference,
          endToEndId: parsed.lines[i].endToEndId,
          remittance: parsed.lines[i].remittance,
        ),
    ];
    StoredBankStatement statement(int count) => StoredBankStatement(
      id: 's',
      format: BankFileFormat.camt053,
      account: parsed.account,
      currency: parsed.currency,
      from: parsed.from,
      to: parsed.to,
      lineCount: count,
      openCount: count,
      sourceSha256: sha256.convert(bytes).toString(),
      statementRef: parsed.statementId,
      openingCents: parsed.openingCents,
      closingCents: parsed.closingCents,
    );
    bool verify(List<StoredBankLine> current, List<int> original) =>
        verifiedBankSourceMovements(
          statement: statement(current.length),
          lines: current,
          original: original,
          limits: limits,
        ) !=
        null;
    final first = lines.first;
    final changed = StoredBankLine(
      id: first.id,
      position: first.position,
      bookingDate: first.bookingDate,
      valueDate: first.valueDate,
      amountCents: first.amountCents + 1,
      currency: first.currency,
      status: first.status,
      transactionId: first.transactionId,
      counterpartyName: first.counterpartyName,
      counterpartyIban: first.counterpartyIban,
      reference: first.reference,
      endToEndId: first.endToEndId,
      remittance: first.remittance,
    );
    final csvStatement = StoredBankStatement(
      id: 'csv',
      format: BankFileFormat.csv,
      account: parsed.account,
      currency: parsed.currency,
      from: parsed.from,
      to: parsed.to,
      lineCount: lines.length,
      openCount: lines.length,
      sourceSha256: sha256.convert(bytes).toString(),
      openingCents: parsed.openingCents,
      closingCents: parsed.closingCents,
    );
    expect(
      verifiedBankSourceMovements(
        statement: csvStatement,
        lines: lines,
        original: bytes,
        limits: limits,
      ),
      isNull,
      reason: 'CSV mapping was not retained and must not be guessed',
    );
    expect(verify(lines, bytes), isTrue);
    final report = BankReconciliationReport(
      statement: statement(lines.length),
      lines: lines,
      acceptedSourceLinesMatch: verify(lines, bytes),
    );
    expect(report.statementDifferenceCents, 0);
    expect(report.unresolved, hasLength(lines.length));
    expect(verify([changed, ...lines.skip(1)], bytes), isFalse);

    StoredBankLine variant({
      int? position,
      DateTime? bookingDate,
      DateTime? valueDate,
      int? amount,
      String? currency,
      String? transaction,
      String? name,
      String? iban,
      String? reference,
      String? endToEnd,
      String? remittance,
    }) => StoredBankLine(
      id: first.id,
      position: position ?? first.position,
      bookingDate: bookingDate ?? first.bookingDate,
      valueDate: valueDate ?? first.valueDate,
      amountCents: amount ?? first.amountCents,
      currency: currency ?? first.currency,
      status: first.status,
      transactionId: transaction ?? first.transactionId,
      counterpartyName: name ?? first.counterpartyName,
      counterpartyIban: iban ?? first.counterpartyIban,
      reference: reference ?? first.reference,
      endToEndId: endToEnd ?? first.endToEndId,
      remittance: remittance ?? first.remittance,
    );
    for (final mismatch in [
      variant(position: 2),
      variant(position: 99),
      variant(bookingDate: first.bookingDate.add(const Duration(days: 1))),
      variant(valueDate: first.valueDate.add(const Duration(days: 1))),
      variant(amount: first.amountCents + 1),
      variant(currency: 'EUR'),
      variant(transaction: '${first.transactionId}x'),
      variant(name: '${first.counterpartyName}x'),
      variant(iban: '${first.counterpartyIban}X'),
      variant(reference: '${first.reference}X'),
      variant(endToEnd: '${first.endToEndId}X'),
      variant(remittance: '${first.remittance}X'),
    ]) {
      expect(verify([mismatch, ...lines.skip(1)], bytes), isFalse);
    }
    StoredBankStatement withMismatch({
      String? account,
      String? currency,
      int? opening,
      int? closing,
    }) => StoredBankStatement(
      id: 's',
      format: BankFileFormat.camt053,
      account: account ?? parsed.account,
      currency: currency ?? parsed.currency,
      from: parsed.from,
      to: parsed.to,
      lineCount: lines.length,
      openCount: lines.length,
      sourceSha256: sha256.convert(bytes).toString(),
      statementRef: parsed.statementId,
      openingCents: opening ?? parsed.openingCents,
      closingCents: closing ?? parsed.closingCents,
    );
    for (final bad in [
      withMismatch(account: 'other'),
      withMismatch(currency: 'EUR'),
      withMismatch(opening: parsed.openingCents! + 1),
      withMismatch(closing: parsed.closingCents! + 1),
    ]) {
      expect(
        analyzeBankSource(
          statement: bad,
          lines: lines,
          original: bytes,
          limits: limits,
        ).issue,
        BankSourceIssue.verificationFailed,
      );
      expect(
        verifiedBankSourceMovements(
          statement: bad,
          lines: lines,
          original: bytes,
          limits: limits,
        ),
        isNull,
      );
    }

    expect(verify(lines.sublist(1), bytes), isFalse);
    // A known trailing transaction can be skipped on import while the RPC's
    // stored count still equals a contiguous fetched prefix.
    final skippedTrailing = lines.take(lines.length - 1).toList();
    expect(verify(skippedTrailing, bytes), isFalse);
    final fileOnly = analyzeBankSource(
      statement: statement(skippedTrailing.length),
      lines: skippedTrailing,
      original: bytes,
      limits: limits,
    );
    expect(fileOnly.difference, 0);
    expect(fileOnly.unmapped, 1);
    expect(fileOnly.issue, isNull);
    final second = lines[1];
    final duplicateRow = StoredBankLine(
      id: first.id,
      position: second.position,
      bookingDate: second.bookingDate,
      valueDate: second.valueDate,
      amountCents: second.amountCents,
      currency: second.currency,
      status: second.status,
      transactionId: second.transactionId,
      counterpartyName: second.counterpartyName,
      counterpartyIban: second.counterpartyIban,
      reference: second.reference,
      endToEndId: second.endToEndId,
      remittance: second.remittance,
    );
    final duplicateRows = [first, duplicateRow, ...lines.skip(2)];
    final duplicateAssociation = analyzeBankSource(
      statement: statement(duplicateRows.length),
      lines: duplicateRows,
      original: bytes,
      limits: limits,
    );
    expect(duplicateAssociation.unmapped, 2);
    expect(duplicateAssociation.difference, 0);

    final badHash = analyzeBankSource(
      statement: statement(lines.length),
      lines: lines,
      original: [...bytes, 32],
      limits: limits,
    );
    expect(badHash.difference, isNull);
    expect(badHash.issue, BankSourceIssue.verificationFailed);
    final duplicateBytes = utf8.encode(
      utf8.decode(bytes).replaceFirst('BANK-0002', 'BANK-0001'),
    );
    final duplicateStatement = StoredBankStatement(
      id: 'duplicate',
      format: BankFileFormat.camt053,
      account: parsed.account,
      currency: parsed.currency,
      from: parsed.from,
      to: parsed.to,
      lineCount: lines.length,
      openCount: lines.length,
      sourceSha256: sha256.convert(duplicateBytes).toString(),
      statementRef: parsed.statementId,
      openingCents: parsed.openingCents,
      closingCents: parsed.closingCents,
    );
    final duplicate = analyzeBankSource(
      statement: duplicateStatement,
      lines: lines,
      original: duplicateBytes,
      limits: limits,
    );
    expect(duplicate.issue, BankSourceIssue.ambiguousIdentity);
    expect(duplicate.difference, isNull);

    final incomplete = BankReconciliationReport(
      statement: statement(skippedTrailing.length),
      lines: skippedTrailing,
      acceptedSourceLinesMatch: verify(skippedTrailing, bytes),
    );
    expect(incomplete.statementDifferenceCents, isNull);

    expect(verify(lines, [...bytes, 32]), isFalse);
    final alteredCurrency = utf8.encode(
      utf8
          .decode(bytes)
          .replaceFirst(
            '<Amt Ccy="CHF">1000.00</Amt>',
            '<Amt Ccy="EUR">1000.00</Amt>',
          ),
    );
    final mixed = StoredBankStatement(
      id: 'mixed',
      format: BankFileFormat.camt053,
      account: parsed.account,
      currency: parsed.currency,
      from: parsed.from,
      to: parsed.to,
      lineCount: lines.length,
      openCount: lines.length,
      statementRef: parsed.statementId,
      sourceSha256: sha256.convert(alteredCurrency).toString(),
      openingCents: parsed.openingCents,
      closingCents: parsed.closingCents,
    );
    expect(
      verifiedBankSourceMovements(
        statement: mixed,
        lines: lines,
        original: alteredCurrency,
        limits: limits,
      ),
      isNull,
      reason: 'a balance in a different currency cannot be summed',
    );

    expect(verify([for (final l in lines) l, lines.first], bytes), isFalse);

    final xml = utf8.decode(bytes);
    final start = xml.indexOf('    <Stmt>');
    final end = xml.indexOf('    </Stmt>', start) + '    </Stmt>'.length;
    final multiBytes = utf8.encode(
      xml.substring(0, end) + xml.substring(start, end) + xml.substring(end),
    );
    final multi = parseBankFile(
      multiBytes,
      format: BankFileFormat.camt053,
      limits: limits,
    );
    final multiLines = [
      for (var i = 0; i < multi.lines.length; i++)
        StoredBankLine(
          id: 'multi-$i',
          position: i + 1,
          bookingDate: multi.lines[i].bookingDate,
          valueDate: multi.lines[i].valueDate,
          amountCents: multi.lines[i].amountCents,
          currency: multi.lines[i].currency,
          status: BankLineStatus.open,
          transactionId: multi.lines[i].transactionId,
          counterpartyName: multi.lines[i].counterpartyName,
          counterpartyIban: multi.lines[i].counterpartyIban,
          reference: multi.lines[i].reference,
          endToEndId: multi.lines[i].endToEndId,
          remittance: multi.lines[i].remittance,
        ),
    ];
    final multiStatement = StoredBankStatement(
      id: 'multi',
      format: BankFileFormat.camt053,
      account: multi.account,
      currency: multi.currency,
      from: multi.from,
      to: multi.to,
      lineCount: multiLines.length,
      openCount: multiLines.length,
      statementRef: multi.statementId,
      sourceSha256: sha256.convert(multiBytes).toString(),
      openingCents: multi.openingCents,
      closingCents: multi.closingCents,
    );
    expect(
      verifiedBankSourceMovements(
        statement: multiStatement,
        lines: multiLines,
        original: multiBytes,
        limits: limits,
      ),
      isNull,
      reason:
          'a file with multiple statements does not prove continuous balances',
    );
  });
}
