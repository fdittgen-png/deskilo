// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The one door a bank file comes in by. The bounds are checked before
// anything is decoded (the size) and after the movements are read (their
// number); a file is then accepted whole — one account, one currency, at
// least one movement — or refused with the problem named. XML is read
// without a document type: a file declaring one (and with it entities that
// could expand) is refused, never resolved. Pure Dart.
import 'package:xml/xml.dart';

import 'bank_statement.dart';
import 'bank_values.dart';
import 'camt.dart';
import 'coda.dart';
import 'csv_statement.dart';
import 'mt940.dart';
import 'ofx.dart';

/// The statement [bytes] carry as [format], read under [limits]; a CSV
/// needs its [csv] mapping.
BankStatement parseBankFile(
  List<int> bytes, {
  required BankFileFormat format,
  required BankFileLimits limits,
  BankCsvMapping? csv,
}) {
  if (bytes.length > limits.maxBytes) {
    throw BankFileException(
      BankFileProblem.tooLarge,
      detail: '${bytes.length} bytes',
    );
  }
  final text = bankText(
    bytes,
    latin1Fallback:
        format == BankFileFormat.coda ||
        format == BankFileFormat.mt940 ||
        format == BankFileFormat.csv,
  );
  final statement = switch (format) {
    BankFileFormat.camt053 ||
    BankFileFormat.camt054 => readCamt(_xmlOf(text), format),
    BankFileFormat.mt940 => readMt940(text),
    BankFileFormat.coda => readCoda(text),
    BankFileFormat.ofx => readOfx(text),
    BankFileFormat.csv => readCsv(
      text,
      csv ??
          (throw const BankFileException(
            BankFileProblem.malformed,
            detail: 'a CSV needs its column mapping',
          )),
    ),
  };
  return _accepted(statement, limits);
}

/// The format [bytes] are most likely in, or null when none is
/// recognised (a CSV is never guessed: its columns need a mapping).
BankFileFormat? detectBankFormat(List<int> bytes) {
  // Latin-1 reads any byte, so detection never refuses.
  final text = bankText(bytes, latin1Fallback: true);
  final head = text.trimLeft();
  if (head.startsWith('<?xml') || head.startsWith('<Document')) {
    if (RegExp(r'<(\w+:)?BkToCstmrStmt[\s>]').hasMatch(text)) {
      return BankFileFormat.camt053;
    }
    if (RegExp(r'<(\w+:)?BkToCstmrDbtCdtNtfctn[\s>]').hasMatch(text)) {
      return BankFileFormat.camt054;
    }
  }
  if (head.startsWith('OFXHEADER') ||
      RegExp('<OFX>', caseSensitive: false).hasMatch(text)) {
    return BankFileFormat.ofx;
  }
  if (text.contains(':20:') && text.contains(':61:')) {
    return BankFileFormat.mt940;
  }
  final first = head.split(RegExp(r'\r?\n')).first.trimRight();
  if (first.length <= _codaRecordLength &&
      RegExp(r'^0{5}\d{6}').hasMatch(first)) {
    return BankFileFormat.coda;
  }
  return null;
}

/// A CODA record is 128 characters (a header may lose trailing blanks).
const int _codaRecordLength = 128;

XmlDocument _xmlOf(String text) {
  if (text.contains('<!DOCTYPE') || text.contains('<!ENTITY')) {
    throw const BankFileException(
      BankFileProblem.malformed,
      detail: 'a document type is not accepted',
    );
  }
  try {
    return XmlDocument.parse(text);
  } on XmlException catch (e, st) {
    Error.throwWithStackTrace(
      BankFileException(BankFileProblem.malformed, detail: e.message),
      st,
    );
  }
}

BankStatement _accepted(BankStatement s, BankFileLimits limits) {
  if (s.lines.length > limits.maxLines) {
    throw BankFileException(
      BankFileProblem.tooManyLines,
      detail: '${s.lines.length} lines',
    );
  }
  if (s.lines.isEmpty) throw const BankFileException(BankFileProblem.empty);
  if (s.account.isEmpty) {
    throw const BankFileException(BankFileProblem.missingAccount);
  }
  for (final l in s.lines) {
    if (l.currency != s.currency) {
      throw BankFileException(
        BankFileProblem.badCurrency,
        line: l.position,
        detail: '${l.currency} on a ${s.currency} account',
      );
    }
  }
  return s;
}
