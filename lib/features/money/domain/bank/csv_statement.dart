// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A bank's spreadsheet export, read through the columns the person maps:
// which column is the booking day, the amount (or a credit and a debit
// column), the currency (or one currency for the file), the counterparty,
// the reference, the text and the bank's own id. A CSV rarely names its
// account, so the person names it. Fields follow RFC 4180 (quotes, doubled
// quotes, separators and line breaks inside quotes); amounts may group
// thousands with spaces, apostrophes or the other separator. Pure Dart.
import 'package:meta/meta.dart';

import 'bank_statement.dart';
import 'bank_values.dart';
import 'structured_reference.dart';

/// How a CSV writes a day.
enum BankCsvDatePattern {
  /// `2026-01-31`
  isoDay,

  /// `31.01.2026`
  dayMonthYearDot,

  /// `31/01/2026`
  dayMonthYearSlash,

  /// `01/31/2026`
  monthDayYearSlash,
}

/// The separators a CSV is read with.
abstract final class BankCsvDelimiters {
  static const String comma = ',';
  static const String semicolon = ';';
  static const String tab = '\t';
  static const List<String> all = [comma, semicolon, tab];
}

/// Which column holds what, by 0-based index.
@immutable
class BankCsvMapping {
  const BankCsvMapping({
    required this.account,
    required this.bookingDate,
    this.delimiter = BankCsvDelimiters.comma,
    this.decimalComma = false,
    this.datePattern = BankCsvDatePattern.isoDay,
    this.header = true,
    this.valueDate,
    this.amount,
    this.credit,
    this.debit,
    this.currency,
    this.fixedCurrency = '',
    this.counterpartyName,
    this.counterpartyIban,
    this.reference,
    this.remittance,
    this.transactionId,
  });

  /// The account the file is about, as the person names it.
  final String account;
  final String delimiter;
  final bool decimalComma;
  final BankCsvDatePattern datePattern;

  /// Whether the first row names the columns (and is not a movement).
  final bool header;
  final int bookingDate;
  final int? valueDate;

  /// One signed amount column, or [credit] and [debit] apart.
  final int? amount;
  final int? credit;
  final int? debit;

  /// A currency column, or [fixedCurrency] for every row.
  final int? currency;
  final String fixedCurrency;
  final int? counterpartyName;
  final int? counterpartyIban;
  final int? reference;
  final int? remittance;
  final int? transactionId;
}

/// The cells of the first row of the CSV [bytes]: the column names the
/// mapping dialog offers.
List<String> csvHeaderOf(List<int> bytes, String delimiter) {
  final rows = _rowsOf(bankText(bytes, latin1Fallback: true), delimiter);
  return rows.isEmpty ? const [] : rows.first.$2;
}

/// The separator [firstLine] most likely uses: the most frequent of the
/// three outside quotes, a comma when none occurs.
String guessCsvDelimiter(String firstLine) {
  final outside = firstLine.replaceAll(RegExp('"[^"]*"'), '');
  var best = BankCsvDelimiters.comma;
  var count = 0;
  for (final d in BankCsvDelimiters.all) {
    final n = d.allMatches(outside).length;
    if (n > count) {
      best = d;
      count = n;
    }
  }
  return best;
}

/// The statement [text] carries under [mapping].
BankStatement readCsv(String text, BankCsvMapping mapping) {
  if (mapping.amount == null &&
      (mapping.credit == null || mapping.debit == null)) {
    throw const BankFileException(
      BankFileProblem.badAmount,
      detail: 'no amount column',
    );
  }
  final rows = _rowsOf(text, mapping.delimiter);
  final body = mapping.header ? rows.skip(1) : rows;
  final lines = <BankLine>[];
  for (final (line, cells) in body) {
    if (cells.every((c) => c.trim().isEmpty)) continue;
    String cell(int? i) =>
        i == null || i >= cells.length ? '' : cells[i].trim();
    final currency = bankCurrency(
      mapping.currency == null ? mapping.fixedCurrency : cell(mapping.currency),
      line: line,
    );
    final separator = mapping.decimalComma ? ',' : '.';
    int money(int? column) {
      final s = cell(column);
      return s.isEmpty
          ? 0
          : bankAmount(
              s,
              currency,
              line: line,
              decimalSeparator: separator,
              grouping: true,
            );
    }

    final cents = mapping.amount != null
        ? bankAmount(
            cell(mapping.amount),
            currency,
            line: line,
            decimalSeparator: separator,
            grouping: true,
          )
        : money(mapping.credit).abs() - money(mapping.debit).abs();
    final booking = _date(cell(mapping.bookingDate), mapping.datePattern, line);
    final value = cell(mapping.valueDate);
    final remittance = cell(mapping.remittance).replaceAll(RegExp(r'\s+'), ' ');
    final reference = normalizeReference(cell(mapping.reference));
    lines.add(
      BankLine(
        position: lines.length + 1,
        bookingDate: booking,
        valueDate: value.isEmpty
            ? booking
            : _date(value, mapping.datePattern, line),
        amountCents: cents,
        currency: currency,
        transactionId: cell(mapping.transactionId),
        counterpartyName: cell(mapping.counterpartyName),
        counterpartyIban: compactIban(cell(mapping.counterpartyIban)),
        reference: isQrReference(reference) || isCreditorReference(reference)
            ? reference
            : structuredReferenceIn('$reference $remittance') ?? '',
        remittance: remittance,
      ),
    );
  }
  return BankStatement(
    format: BankFileFormat.csv,
    account: mapping.account.trim(),
    currency: lines.isEmpty ? '' : lines.first.currency,
    lines: lines,
  );
}

DateTime _date(String text, BankCsvDatePattern pattern, int line) {
  final re = switch (pattern) {
    BankCsvDatePattern.isoDay => RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})'),
    BankCsvDatePattern.dayMonthYearDot => RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$',
    ),
    BankCsvDatePattern.dayMonthYearSlash ||
    BankCsvDatePattern.monthDayYearSlash => RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
    ),
  };
  final m = re.firstMatch(text);
  if (m == null) {
    throw BankFileException(BankFileProblem.badDate, line: line, detail: text);
  }
  final [a, b, c] = [for (var g = 1; g <= 3; g++) int.parse(m.group(g)!)];
  return switch (pattern) {
    BankCsvDatePattern.isoDay => bankDay(a, b, c, line: line),
    BankCsvDatePattern.monthDayYearSlash => bankDay(c, a, b, line: line),
    _ => bankDay(c, b, a, line: line),
  };
}

/// The rows of [text] with the 1-based line each starts on.
List<(int, List<String>)> _rowsOf(String text, String delimiter) =>
    (_CsvReader(text, delimiter)..read()).rows;

class _CsvReader {
  _CsvReader(this.text, this.delimiter);

  final String text;
  final String delimiter;
  final rows = <(int, List<String>)>[];
  var _cells = <String>[];
  final _cell = StringBuffer();
  var _line = 1;
  var _rowStart = 1;

  void read() {
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quoted) {
        (i, quoted) = _inQuotes(i, ch);
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == delimiter) {
        _endCell();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && _next(i) == '\n') i++;
        _endRow();
      } else {
        _cell.write(ch);
      }
    }
    if (quoted) {
      throw BankFileException(
        BankFileProblem.malformed,
        line: _rowStart,
        detail: 'an unclosed quote',
      );
    }
    if (_cell.isNotEmpty || _cells.isNotEmpty) {
      _endCell();
      rows.add((_rowStart, _cells));
    }
  }

  String? _next(int i) => i + 1 < text.length ? text[i + 1] : null;

  /// One character inside quotes: a doubled quote is a quote, a single one
  /// closes them. Returns where the scan resumes and whether still quoted.
  (int, bool) _inQuotes(int i, String ch) {
    if (ch != '"') {
      if (ch == '\n') _line++;
      _cell.write(ch);
      return (i, true);
    }
    if (_next(i) == '"') {
      _cell.write('"');
      return (i + 1, true);
    }
    return (i, false);
  }

  void _endCell() {
    _cells.add(_cell.toString());
    _cell.clear();
  }

  void _endRow() {
    _endCell();
    rows.add((_rowStart, _cells));
    _cells = <String>[];
    _line++;
    _rowStart = _line;
  }
}
