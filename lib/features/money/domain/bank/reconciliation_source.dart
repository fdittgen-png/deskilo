// SPDX-License-Identifier: AGPL-3.0-or-later
// Proof of correspondence to one retained source file, not proof that the
// bank supplied all movements of an account or that the books reconcile.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import 'bank_file.dart';
import 'bank_records.dart';
import 'bank_statement.dart';
import 'bank_statement_fit.dart';
import 'reconciliation_report.dart';

List<StoredBankLine>? verifiedBankSourceMovements({
  required StoredBankStatement statement,
  required List<StoredBankLine> lines,
  required List<int> original,
  required BankFileLimits limits,
}) {
  final source = _verifiedSource(statement, lines, original, limits);
  if (source == null) return null;
  if (lines.length != statement.lineCount ||
      source.lines.length != lines.length ||
      lines.map((line) => line.id).toSet().length != lines.length ||
      lines.map((line) => line.position).toSet().length != lines.length) {
    return null;
  }
  final byPosition = {for (final line in lines) line.position: line};
  for (var i = 0; i < source.lines.length; i++) {
    final expected = source.lines[i];
    final actual = byPosition[i + 1];
    if (actual == null || !_sameMovement(expected, actual)) return null;
  }
  return [for (var i = 0; i < source.lines.length; i++) byPosition[i + 1]!];
}

/// File arithmetic is independent of the separately read retained-row status.
/// Empty or repeated identities cannot establish distinct accepted movements.
({int? difference, int? unmapped, BankSourceIssue? issue}) analyzeBankSource({
  required StoredBankStatement statement,
  required List<StoredBankLine> lines,
  required List<int> original,
  required BankFileLimits limits,
}) {
  final source = _verifiedSource(statement, lines, original, limits);
  if (source == null) {
    return (
      difference: null,
      unmapped: null,
      issue: BankSourceIssue.verificationFailed,
    );
  }
  final ids = source.lines.map((line) => line.transactionId.trim()).toList();
  if (ids.any((id) => id.isEmpty) || ids.toSet().length != ids.length) {
    return (
      difference: null,
      unmapped: null,
      issue: BankSourceIssue.ambiguousIdentity,
    );
  }
  final opening = source.openingCents;
  final closing = source.closingCents;
  if (opening == null ||
      closing == null ||
      source.lines.any((line) => line.currency != source.currency)) {
    return (
      difference: null,
      unmapped: null,
      issue: BankSourceIssue.verificationFailed,
    );
  }
  final byPosition = <int, StoredBankLine>{};
  final duplicatePositions = <int>{};
  for (final line in lines) {
    if (byPosition.containsKey(line.position)) {
      duplicatePositions.add(line.position);
    }
    byPosition[line.position] = line;
  }
  var unmapped = 0;
  for (var i = 0; i < source.lines.length; i++) {
    final position = i + 1;
    final line = byPosition[position];
    if (line == null ||
        duplicatePositions.contains(position) ||
        !_sameMovement(source.lines[i], line)) {
      unmapped++;
    }
  }
  return (
    difference:
        closing -
        opening -
        source.lines.fold<int>(0, (sum, line) => sum + line.amountCents),
    unmapped: unmapped,
    issue: null,
  );
}

BankStatement? _verifiedSource(
  StoredBankStatement statement,
  List<StoredBankLine> lines,
  List<int> original,
  BankFileLimits limits,
) {
  // Other parsers do not expose enough balance provenance to prove that
  // opening and closing are the same currency and one coherent statement.
  if (statement.format != BankFileFormat.camt053 ||
      statement.sourceSha256.isEmpty ||
      sha256.convert(original).toString() != statement.sourceSha256) {
    return null;
  }
  BankStatement source;
  try {
    source = fitBankStatement(
      parseBankFile(original, format: statement.format, limits: limits),
    );
  } on BankFileException {
    return null;
  } on FormatException {
    return null;
  }
  if (!_singleCamtBalanceScope(original, source.currency)) return null;
  if (source.account.trim().toUpperCase() != statement.account ||
      source.currency != statement.currency ||
      source.statementId != statement.statementRef ||
      source.openingCents != statement.openingCents ||
      source.closingCents != statement.closingCents) {
    return null;
  }
  return source;
}

bool _sameMovement(BankLine expected, StoredBankLine actual) =>
    expected.bookingDate == actual.bookingDate &&
    expected.valueDate == actual.valueDate &&
    expected.amountCents == actual.amountCents &&
    expected.currency == actual.currency &&
    expected.transactionId.trim() == actual.transactionId &&
    expected.counterpartyName == actual.counterpartyName &&
    expected.counterpartyIban == actual.counterpartyIban &&
    expected.reference == actual.reference &&
    expected.endToEndId == actual.endToEndId &&
    expected.remittance == actual.remittance;

// readCamt can combine reports and accepts balance amounts with a currency
// different from the account. Restrict arithmetic to a single statement
// with explicit matching currencies and unambiguous balance directions.
bool _singleCamtBalanceScope(List<int> original, String currency) {
  try {
    final doc = XmlDocument.parse(utf8.decode(original));
    final messages = doc.rootElement.childElements
        .where((e) => e.name.local == 'BkToCstmrStmt')
        .toList();
    if (messages.length != 1) return false;
    final statements = messages.single.childElements
        .where((e) => e.name.local == 'Stmt')
        .toList();
    if (statements.length != 1) return false;
    final balances = statements.single.childElements
        .where((e) => e.name.local == 'Bal')
        .toList();
    final opening = <XmlElement>[];
    final closing = <XmlElement>[];
    for (final balance in balances) {
      final codes = balance.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'Cd')
          .map((e) => e.innerText)
          .toList();
      if (codes.contains('PRCD')) return false;
      if (codes.contains('OPBD')) opening.add(balance);
      if (codes.contains('CLBD')) closing.add(balance);
    }
    if (opening.length != 1 || closing.length != 1) return false;
    for (final balance in [opening.single, closing.single]) {
      final amounts = balance.childElements
          .where((e) => e.name.local == 'Amt')
          .toList();
      final directions = balance.childElements
          .where((e) => e.name.local == 'CdtDbtInd')
          .toList();
      if (amounts.length != 1 ||
          amounts.single.getAttribute('Ccy') != currency ||
          directions.length != 1 ||
          !{'CRDT', 'DBIT'}.contains(directions.single.innerText)) {
        return false;
      }
    }
    return true;
  } on XmlException {
    return false;
  } on FormatException {
    return false;
  }
}
