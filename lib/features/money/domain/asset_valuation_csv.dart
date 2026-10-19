// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/settings/setting_defaults.g.dart';
import '../../../core/time/date_text.dart';
import 'asset_valuation_types.dart';

/// #2576 (C2) — the documented UTF-8 CSV of the accountant's valuations,
/// read strictly: every problem is reported with its line, and a file with a
/// problem is not usable.

/// The columns of the documented UTF-8 CSV, in order.
const _columns = [
  'AssetNumber',
  'Basis',
  'PeriodFrom',
  'PeriodTo',
  'Currency',
  'OpeningMinor',
  'AdditionsMinor',
  'DisposalsMinor',
  'DepreciationMinor',
  'ImpairmentMinor',
  'ClosingMinor',
  'ExternalReference',
];

/// The header line of the documented CSV.
String get valuationHeaderLine => _columns.join(',');

/// One cell of a CSV line written by the app: quoted when it must be.
String valuationCsvCell(String cell) {
  final text = cell.trim();
  return text.contains(RegExp('[",\\n\\r]'))
      ? '"${text.replaceAll('"', '""')}"'
      : text;
}

/// The largest figure a row may state: what every platform keeps exactly.
const _maxMinor = 9007199254740991;

/// What is wrong with a line of the CSV. The wording belongs to the screen.
enum ValuationIssueKind {
  empty,
  tooManyRows,
  header,
  columnCount,
  assetNumber,
  basis,
  date,
  period,
  currency,
  minor,
  mixed,
  duplicateAsset,
}

class ValuationIssue {
  const ValuationIssue(this.line, this.kind, [this.detail = '']);

  /// 1-based line of the file; 0 for the file as a whole.
  final int line;
  final ValuationIssueKind kind;

  /// The offending column or value, for the message.
  final String detail;

  @override
  String toString() => '$line:${kind.name}:$detail';
}

/// What the file says about itself and its rows, or why it cannot be used.
class ValuationCsv {
  const ValuationCsv({
    required this.issues,
    required this.sha256Hex,
    this.basis,
    this.periodFrom,
    this.periodTo,
    this.currency = '',
    this.rows = const [],
  });

  final List<ValuationIssue> issues;
  final String sha256Hex;
  final ValuationBasis? basis;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final String currency;
  final List<ValuationRowDraft> rows;

  bool get usable => issues.isEmpty && rows.isNotEmpty;

  int get mismatches =>
      rows.where((r) => r.bridge == ValuationBridge.mismatch).length;
}

/// Reads RFC 4180 text with comma separators into rows of cells; null for an
/// unterminated quote. Blank lines are skipped.
class _CsvScanner {
  _CsvScanner(this._text);

  final String _text;
  final _rows = <List<String>>[];
  var _row = <String>[];
  final _cell = StringBuffer();
  var _quoted = false;
  var _started = false;

  List<List<String>>? scan() {
    for (var i = 0; i < _text.length; i++) {
      i = _step(i);
    }
    if (_quoted) return null;
    if (_started || _cell.isNotEmpty) _endRow();
    return _rows;
  }

  /// Handles the character at [i]; returns the index of the last one used.
  int _step(int i) {
    final c = _text[i];
    if (_quoted) return _inQuotes(i, c);
    switch (c) {
      case '"' when _cell.isEmpty:
        _quoted = true;
        _started = true;
      case ',':
        _endCell();
        _started = true;
      case '\n' || '\r':
        final crlf = c == '\r' && i + 1 < _text.length && _text[i + 1] == '\n';
        _endRow();
        return crlf ? i + 1 : i;
      default:
        _cell.write(c);
        _started = true;
    }
    return i;
  }

  int _inQuotes(int i, String c) {
    if (c != '"') {
      _cell.write(c);
      return i;
    }
    if (i + 1 < _text.length && _text[i + 1] == '"') {
      _cell.write('"');
      return i + 1;
    }
    _quoted = false;
    return i;
  }

  void _endCell() {
    _row.add(_cell.toString());
    _cell.clear();
  }

  void _endRow() {
    _endCell();
    if (!(_row.length == 1 && _row.single.trim().isEmpty)) _rows.add(_row);
    _row = <String>[];
    _started = false;
  }
}

final _integer = RegExp(r'^[+-]?\d+$');
final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _currencyCode = RegExp(r'^[A-Z]{3}$');

DateTime? _date(String s) {
  final m = _isoDate.firstMatch(s);
  if (m == null) return null;
  final d = DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
  return isoDay(d) == s ? d : null;
}

/// Reads the data lines of a file whose header was accepted, collecting every
/// problem with its line. A batch has one basis, one period and one currency
/// (the first line states them) and names an asset once.
class _RowReader {
  final issues = <ValuationIssue>[];
  final rows = <ValuationRowDraft>[];
  final _seen = <int>{};
  ValuationBasis? basis;
  DateTime? from;
  DateTime? to;
  String? currency;

  void read(int line, List<String> c) {
    if (c.length != _columns.length) {
      _issue(line, ValuationIssueKind.columnCount, '${c.length}');
      return;
    }
    final no = _integer.hasMatch(c[0].trim()) ? int.tryParse(c[0].trim()) : null;
    if (no == null || no < 1) {
      _issue(line, ValuationIssueKind.assetNumber, c[0]);
      return;
    }
    if (!_seen.add(no)) _issue(line, ValuationIssueKind.duplicateAsset, '$no');
    _batchColumns(line, c);
    rows.add(
      ValuationRowDraft(
        assetNumber: no,
        externalReference: c[11].trim(),
        openingMinor: _minor(c[5], line, 5),
        additionsMinor: _minor(c[6], line, 6),
        disposalsMinor: _minor(c[7], line, 7),
        depreciationMinor: _minor(c[8], line, 8),
        impairmentMinor: _minor(c[9], line, 9),
        closingMinor: _minor(c[10], line, 10),
      ),
    );
  }

  void _issue(int line, ValuationIssueKind kind, [String detail = '']) =>
      issues.add(ValuationIssue(line, kind, detail));

  /// Basis, period and currency of a line, and that they agree with the first.
  void _batchColumns(int line, List<String> c) {
    final b = ValuationBasis.of(c[1].trim().toLowerCase());
    final f = _date(c[2].trim());
    final t = _date(c[3].trim());
    final cur = c[4].trim().toUpperCase();
    if (b == null) _issue(line, ValuationIssueKind.basis, c[1]);
    if (f == null || t == null) {
      _issue(line, ValuationIssueKind.date, f == null ? c[2] : c[3]);
    } else if (t.isBefore(f)) {
      _issue(line, ValuationIssueKind.period);
    }
    final validCurrency = _currencyCode.hasMatch(cur);
    if (!validCurrency) _issue(line, ValuationIssueKind.currency, c[4]);
    if (b == null || f == null || t == null || !validCurrency) return;
    basis ??= b;
    from ??= f;
    to ??= t;
    currency ??= cur;
    if (b != basis || f != from || t != to || cur != currency) {
      _issue(line, ValuationIssueKind.mixed);
    }
  }

  /// A signed decimal integer, exactly; blank is unknown, anything else (a
  /// decimal point, an exponent, a formula, too large) is a problem.
  int? _minor(String raw, int line, int column) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final value = _integer.hasMatch(s) ? BigInt.tryParse(s) : null;
    if (value == null || value.abs() > BigInt.from(_maxMinor)) {
      _issue(line, ValuationIssueKind.minor, _columns[column]);
      return null;
    }
    return value.toInt();
  }
}

ValuationCsv _refused(String hash, ValuationIssue issue) =>
    ValuationCsv(issues: [issue], sha256Hex: hash);

/// Reads the documented CSV. Every problem is reported with its line; a
/// file with a problem is not usable. Blank figures are unknown, signed
/// decimal integers are exact, anything else (a decimal point, an exponent, a
/// formula) is refused.
ValuationCsv readValuationCsv(
  String content, {
  int maxRows = SettingDefaults.assetsValuationMaxRows,
}) {
  final text = content.startsWith('\uFEFF') ? content.substring(1) : content;
  final hash = sha256.convert(utf8.encode(content)).toString();
  final cells = _CsvScanner(text).scan();
  if (cells == null) {
    return _refused(
      hash,
      const ValuationIssue(0, ValuationIssueKind.header, 'quote'),
    );
  }
  if (cells.isEmpty) {
    return _refused(hash, const ValuationIssue(0, ValuationIssueKind.empty));
  }
  final header = [for (final c in cells.first) c.trim()];
  if (header.length != _columns.length ||
      !_sameColumns(header)) {
    return _refused(
      hash,
      ValuationIssue(1, ValuationIssueKind.header, header.join(',')),
    );
  }
  final data = cells.skip(1).toList();
  if (data.isEmpty) {
    return _refused(hash, const ValuationIssue(0, ValuationIssueKind.empty));
  }
  if (data.length > maxRows) {
    return _refused(
      hash,
      ValuationIssue(0, ValuationIssueKind.tooManyRows, '$maxRows'),
    );
  }
  final reader = _RowReader();
  for (var i = 0; i < data.length; i++) {
    reader.read(i + 2, data[i]);
  }
  return ValuationCsv(
    issues: reader.issues,
    sha256Hex: hash,
    basis: reader.basis,
    periodFrom: reader.from,
    periodTo: reader.to,
    currency: reader.currency ?? '',
    rows: reader.rows,
  );
}

bool _sameColumns(List<String> header) {
  for (var i = 0; i < header.length; i++) {
    if (header[i] != _columns[i]) return false;
  }
  return true;
}

/// A synthetic sample of the format, for the accountant to start from.
String valuationSampleCsv() =>
    '${_columns.join(',')}\n'
    '1,book,2026-01-01,2026-12-31,EUR,120000,0,0,24000,0,96000,FA-0001\n'
    '2,book,2026-01-01,2026-12-31,EUR,,,,,,,FA-0002\n';
