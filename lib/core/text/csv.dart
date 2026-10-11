// SPDX-License-Identifier: AGPL-3.0-or-later

/// One CSV cell writer for every file the app exports (#2385).
///
/// Before this, five writers each had a local `q()` with its own edge
/// cases, and only the accountant CSV guarded against formula injection.
/// Every writer now goes through [csvCell], so a fix lands everywhere.
library;

/// How a cell escapes a double quote — the one thing the importers we
/// write for disagree on.
enum CsvDialect {
  /// RFC 4180: a quote inside a cell is doubled (`"` → `""`).
  rfc4180,

  /// Sage 50's import wizard does not read a doubled quote; a quote
  /// becomes an apostrophe.
  sage,

  /// DATEV EXTF: as [sage], and a `;` (DATEV's separator) becomes a
  /// space; the cell is trimmed.
  datev,
}

final _control = RegExp(r'[\x00-\x1F\x7F]+');
final _controlOrSemicolon = RegExp(r'[\x00-\x1F\x7F;]+');
final _formulaStart = RegExp(r'^[=+\-@]');

/// [value] as one quoted CSV cell in [dialect].
///
/// - **Control characters** (tabs, carriage returns, line feeds, the
///   rest of C0 and DEL) become one space, so none of them can end a
///   row or open a cell.
/// - **Formula injection** (OWASP "CSV injection"): quoting alone does
///   not stop a spreadsheet from evaluating `=…`, so a cell whose first
///   character could start a formula (`=`, `+`, `-`, `@`) gets a leading
///   apostrophe, which every major spreadsheet reads as "this is text".
///   Pass text only — a number never goes through here, so a credit
///   note's `-12.00` stays a number.
/// - [maxLength] cuts longer text with an ellipsis.
/// - An empty or null value is written as nothing, or as `""` when
///   [quoteEmpty] is set (the files whose readers expect every text
///   column quoted).
String csvCell(
  String? value, {
  CsvDialect dialect = CsvDialect.rfc4180,
  bool quoteEmpty = false,
  int? maxLength,
}) {
  if (value == null || value.isEmpty) return quoteEmpty ? '""' : '';
  var text = switch (dialect) {
    CsvDialect.datev => value.replaceAll(_controlOrSemicolon, ' ').trim(),
    _ => value.replaceAll(_control, ' '),
  };
  if (maxLength != null && text.length > maxLength) {
    text = '${text.substring(0, maxLength - 1)}…';
  }
  if (_formulaStart.hasMatch(text)) text = "'$text";
  final escaped = switch (dialect) {
    CsvDialect.rfc4180 => text.replaceAll('"', '""'),
    CsvDialect.sage || CsvDialect.datev => text.replaceAll('"', "'"),
  };
  return '"$escaped"';
}
