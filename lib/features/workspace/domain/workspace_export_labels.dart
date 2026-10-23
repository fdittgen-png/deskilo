// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2861 — the workbook in the reader's language. The builders keep writing
// stable English keys (`Check-ins`, `starts_at`): those keys are the CSV
// machine copy's, which formulas and importers rely on whatever the
// reader's language. This pass gives the person-facing workbook its sheet
// names and headers in the reader's words, a key without a translation in
// readable form, and an "About this export" sheet first. Pure Dart: the
// words come in through [ExportLabels].
import '../../../core/files/xlsx.dart';

/// The words the workbook is written in.
class ExportLabels {
  const ExportLabels({
    required this.sheet,
    required this.column,
    required this.about,
    this.value,
    this.process,
    this.feature,
  });

  /// A sheet's name by its key; the key itself when there is none.
  final String Function(String key) sheet;

  /// A column's header by its key; the key itself when there is none.
  final String Function(String key) column;

  /// The About sheet's own words.
  final ExportAboutLabels about;

  /// A status or type value by its stored word; the word itself when there
  /// is none. Only the columns in [_exportValueColumns] are read through it.
  final String Function(String key)? value;

  /// A process's and a feature's name by their keys (the Features sheet).
  final String Function(String key)? process;
  final String Function(String key)? feature;
}

/// #2861 — the columns that hold a stored word (a status, a kind) rather
/// than a name or a free text: the reader sees them in their language.
const _exportValueColumns = {
  'status',
  'kind',
  'category',
  'state',
  'decision',
  'action',
  'resource_kind',
  'parking_kind',
  'area_kind',
  'orientation',
  'overage_policy',
  'co_owner',
};

/// The About sheet's words.
class ExportAboutLabels {
  const ExportAboutLabels({
    required this.title,
    required this.workspace,
    required this.generatedOn,
    required this.timeZone,
    required this.currency,
    required this.schema,
    required this.contents,
    required this.sheet,
    required this.rows,
    required this.machineCopy,
  });

  final String title;
  final String workspace;
  final String generatedOn;
  final String timeZone;
  final String currency;
  final String schema;
  final String contents;
  final String sheet;
  final String rows;

  /// One sentence on the CSV copy in `data/`.
  final String machineCopy;
}

/// The stable key of a sheet name: `Check-ins` → `check_ins`.
String exportKeyOf(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');

/// A key in readable form: `created_at` → `Created at`.
String _humanize(String key) {
  final words = key.replaceAll('_', ' ').trim();
  return words.isEmpty ? key : words[0].toUpperCase() + words.substring(1);
}

String _word(String Function(String) lookup, String key) {
  final word = lookup(key);
  return word.isEmpty || word == key ? _humanize(key) : word;
}

/// Whether [header] names an identifier (`id`, `member_id`): a reader
/// looks for the names and amounts first, so these go last.
bool _isIdColumn(Object? header) =>
    header is String && (header == 'id' || header.endsWith('_id'));

/// [sheets] with their names and header rows in [labels]' words, their
/// id columns last and a totals row's label translated; the cells
/// themselves are unchanged. Names stay unique after Excel's 31-character
/// cut. The CSV copy keeps the builders' order.
List<XlsxSheet> localizeExportSheets(
  List<XlsxSheet> sheets,
  ExportLabels labels,
) {
  final taken = <String>{};
  String unique(String name) {
    var candidate = name.length <= 31 ? name : name.substring(0, 31);
    for (var n = 2; !taken.add(candidate.toLowerCase()); n++) {
      final suffix = ' $n';
      candidate =
          (name.length + suffix.length <= 31
              ? name
              : name.substring(0, 31 - suffix.length)) +
          suffix;
    }
    return candidate;
  }

  // The lookup a column's stored words are read through, if any.
  String Function(String)? lookupFor(Object? column) => switch (column) {
    'field' => labels.column,
    'process' => labels.process,
    'feature' => labels.feature,
    final String c when _exportValueColumns.contains(c) => labels.value,
    _ => null,
  };

  List<Object?> values(List<Object?> header, List<Object?> row) => [
    for (final (i, cell) in row.indexed)
      switch (i < header.length ? lookupFor(header[i]) : null) {
        final lookup? when cell is String => _word(lookup, cell),
        _ => cell,
      },
  ];

  return [
    for (final s in sheets.map(_idsLast))
      XlsxSheet(
        name: unique(_word(labels.sheet, exportKeyOf(s.name))),
        rows: [
          if (s.rows.isNotEmpty)
            [
              for (final h in s.rows.first)
                if (h is String) _word(labels.column, h) else h,
            ],
          for (final row in s.rows.skip(1)) values(s.rows.first, row),
        ],
        totals: s.totals == null ? null : _word(labels.column, s.totals!),
      ),
  ];
}

/// [sheet] with its id columns moved after the others, in their order.
XlsxSheet _idsLast(XlsxSheet sheet) {
  if (sheet.rows.isEmpty) return sheet;
  final header = sheet.rows.first;
  final order = [
    for (final (i, h) in header.indexed)
      if (!_isIdColumn(h)) i,
    for (final (i, h) in header.indexed)
      if (_isIdColumn(h)) i,
  ];
  return XlsxSheet(
    name: sheet.name,
    totals: sheet.totals,
    rows: [
      for (final row in sheet.rows)
        [
          for (final i in order) if (i < row.length) row[i] else null,
          // A row longer than its header keeps its extra cells.
          ...row.skip(header.length),
        ],
    ],
  );
}

/// The first sheet: what this export is, then one line per sheet with its
/// row count.
XlsxSheet exportAboutSheet({
  required ExportAboutLabels labels,
  required String workspaceName,
  required DateTime generatedAt,
  required String timeZone,
  required String currency,
  required int? schemaVersion,
  required List<XlsxSheet> sheets,
}) => XlsxSheet(
  name: labels.title,
  rows: [
    [labels.title, null],
    [labels.workspace, workspaceName],
    [labels.generatedOn, generatedAt],
    [labels.timeZone, timeZone],
    [labels.currency, currency],
    [labels.schema, schemaVersion],
    [labels.machineCopy, null],
    [null, null],
    [labels.contents, null],
    [labels.sheet, labels.rows],
    for (final s in sheets)
      [s.name, if (s.rows.isEmpty) 0 else s.rows.length - 1],
  ],
);

/// A sheet as CSV under its stable keys (RFC 4180, UTF-8): the machine
/// copy. Dates are ISO 8601 at the workspace clock, a day `yyyy-mm-dd`, an
/// amount its number.
String exportSheetCsv(XlsxSheet sheet) {
  String cell(Object? v) {
    final text = switch (v) {
      null => '',
      final DateTime d => d.toIso8601String(),
      final XlsxDate d => d.value.toIso8601String().substring(0, 10),
      final XlsxAmount a => '${a.value}',
      _ => '$v',
    };
    return RegExp('[",\n\r]').hasMatch(text)
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  return '${[for (final row in sheet.rows) row.map(cell).join(',')].join('\r\n')}\r\n';
}
