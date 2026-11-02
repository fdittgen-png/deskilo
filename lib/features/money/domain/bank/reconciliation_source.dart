// SPDX-License-Identifier: AGPL-3.0-or-later
// Proof of correspondence to one retained source file, not proof that the
// bank supplied all movements of an account or that the books reconcile.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import 'bank_file.dart';
import 'bank_records.dart';
import 'bank_statement.dart';
import 'reconciliation_overlap.dart';

List<StoredBankLine>? verifiedBankSourceMovements({
  required StoredBankStatement statement,
  required List<StoredBankLine> lines,
  required List<int> original,
  required BankFileLimits limits,
  List<BankCanonicalLine> candidates = const [],
}) {
  final source = _verifiedSource(statement, lines, original, limits);
  if (source == null) return null;
  return mapBankSourceMovements(
    source: source,
    ownLines: lines,
    candidates: candidates,
  );
}

/// Only query other statements when a valid source actually has omitted rows.
bool bankSourceNeedsCanonicalLookup({
  required StoredBankStatement statement,
  required List<StoredBankLine> lines,
  required List<int> original,
  required BankFileLimits limits,
}) {
  final source = _verifiedSource(statement, lines, original, limits);
  return source != null && source.lines.length > lines.length;
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
    source = parseBankFile(original, format: statement.format, limits: limits);
  } on BankFileException {
    return null;
  } on FormatException {
    return null;
  }
  if (!_singleCamtBalanceScope(original, source.currency)) return null;
  if (source.account != statement.account ||
      source.currency != statement.currency ||
      source.statementId != statement.statementRef ||
      source.openingCents != statement.openingCents ||
      source.closingCents != statement.closingCents ||
      lines.length != statement.lineCount) {
    return null;
  }
  return source;
}

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
