// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The values every bank file parser reads the same way: an amount as an
// exact number of the currency's minor units (never a double), a calendar
// day that really exists, an ISO 4217 code. A value that is not one of
// these refuses the whole file with the problem named. Pure Dart.
import 'dart:convert';

import 'package:meta/meta.dart';

import 'bank_statement.dart';

/// The ISO 4217 minor-unit exponents that are not 2. Not a choice: the
/// standard fixes them.
@visibleForTesting
abstract final class CurrencyExponents {
  /// The exponent of every currency the map does not name.
  static const int standard = 2;

  static const Map<String, int> nonStandard = {
    'BHD': 3,
    'CLP': 0,
    'IQD': 3,
    'ISK': 0,
    'JOD': 3,
    'JPY': 0,
    'KRW': 0,
    'KWD': 3,
    'LYD': 3,
    'OMR': 3,
    'TND': 3,
    'VND': 0,
  };

  /// The minor-unit exponent of [currency].
  static int of(String currency) => nonStandard[currency] ?? standard;
}

/// The most integer digits an amount may carry: beyond it the figure is not
/// a bank movement and would overflow the stored integer.
const int _maxIntegerDigits = 13;

final _ccy = RegExp(r'^[A-Z]{3}$');
final _plain = RegExp(r'^(\d+)(?:\.(\d*))?$');

/// [code] upper-cased when it is an ISO 4217 code; refuses the file
/// otherwise.
String bankCurrency(String code, {int? line}) {
  final c = code.trim().toUpperCase();
  if (!_ccy.hasMatch(c)) {
    throw BankFileException(
      BankFileProblem.badCurrency,
      line: line,
      detail: code,
    );
  }
  return c;
}

/// [text] in minor units of [currency]: an optional sign, digits grouped
/// by spaces, apostrophes or the other separator, and [decimalSeparator].
/// Decimals beyond the currency's exponent must be zeros.
int bankAmount(
  String text,
  String currency, {
  int? line,
  String decimalSeparator = '.',
}) {
  BankFileException bad() =>
      BankFileException(BankFileProblem.badAmount, line: line, detail: text);
  var s = text.trim();
  var negative = false;
  if (s.startsWith('-') || s.startsWith('+')) {
    negative = s.startsWith('-');
    s = s.substring(1).trim();
  }
  final group = decimalSeparator == ',' ? '.' : ',';
  s = s.replaceAll(RegExp("[ '  ]"), '').replaceAll(group, '');
  if (decimalSeparator != '.') s = s.replaceAll(decimalSeparator, '.');
  final m = _plain.firstMatch(s);
  if (m == null) throw bad();
  final whole = m.group(1)!.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (whole.length > _maxIntegerDigits) throw bad();
  final exponent = CurrencyExponents.of(currency);
  var fraction = m.group(2) ?? '';
  if (fraction.length > exponent) {
    if (fraction.substring(exponent).replaceAll('0', '').isNotEmpty) {
      throw bad();
    }
    fraction = fraction.substring(0, exponent);
  }
  final units = int.parse('$whole${fraction.padRight(exponent, '0')}');
  return negative ? -units : units;
}

/// The day [year]-[month]-[day] at UTC midnight; refuses the file when it
/// is not a calendar day.
DateTime bankDay(int year, int month, int day, {int? line}) {
  final d = DateTime.utc(year, month, day);
  if (d.year != year || d.month != month || d.day != day) {
    throw BankFileException(
      BankFileProblem.badDate,
      line: line,
      detail: '$year-$month-$day',
    );
  }
  return d;
}

/// An ISO day (`YYYY-MM-DD`, optionally followed by a time) as written, the
/// time and its offset ignored: the bank's own calendar day.
DateTime bankIsoDay(String text, {int? line}) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text.trim());
  if (m == null) {
    throw BankFileException(BankFileProblem.badDate, line: line, detail: text);
  }
  return bankDay(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    line: line,
  );
}

/// [iban] upper-cased without spaces.
String compactIban(String iban) =>
    iban.replaceAll(RegExp(r'\s'), '').toUpperCase();

/// [bytes] as text: UTF-8 without its byte-order mark; when they are not
/// UTF-8 and [latin1Fallback] holds (the fixed-record formats older bank
/// systems still write in ISO 8859-1), Latin-1. Otherwise the file is
/// refused.
String bankText(List<int> bytes, {required bool latin1Fallback}) {
  const bom = [0xEF, 0xBB, 0xBF];
  final body =
      bytes.length >= bom.length &&
          bytes[0] == bom[0] &&
          bytes[1] == bom[1] &&
          bytes[2] == bom[2]
      ? bytes.sublist(bom.length)
      : bytes;
  try {
    return utf8.decode(body);
  } on FormatException catch (e, st) {
    if (latin1Fallback) return latin1.decode(body);
    Error.throwWithStackTrace(
      BankFileException(BankFileProblem.malformed, detail: e.message),
      st,
    );
  }
}
