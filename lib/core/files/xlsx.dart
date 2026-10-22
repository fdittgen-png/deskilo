// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Minimal XLSX writer (#395): a workbook is a ZIP of XML parts, and this
/// writes exactly the parts a reader needs — nothing more.
///
/// In-house on purpose, the `pdf`-over-`printing` decision again: the
/// export needs "rows of values in named tabs", not a spreadsheet engine,
/// and `xml` + `archive` are already in the tree. Strings go in as INLINE
/// strings (`t="inlineStr"`), which sidesteps the shared-strings table;
/// numbers as native number cells so Excel can sum them; everything else
/// as text.
///
/// #2861 — a sheet a person can read: a bold, filled, frozen header row
/// with a filter on it, columns as wide as what they hold, real booleans,
/// and dates as real Excel dates (sortable, filterable) at the wall-clock
/// time they carry — the caller converts an instant to the workspace's
/// time zone first. [XlsxDate] marks a day without a time, [XlsxAmount] a
/// money amount shown with two decimals.
class XlsxSheet {
  const XlsxSheet({required this.name, required this.rows});

  /// Tab name. Sanitised on write: Excel refuses names longer than 31
  /// chars or containing []:*?/\ — silently producing an unopenable file
  /// otherwise.
  final String name;

  /// First row is the header. Cells: String, num, bool, DateTime,
  /// [XlsxDate], [XlsxAmount] or null.
  final List<List<Object?>> rows;
}

/// #2861 — a calendar day, written as a date without a time.
class XlsxDate {
  const XlsxDate(this.value);
  final DateTime value;
}

/// #2861 — a money amount, written as a number with two decimals.
class XlsxAmount {
  const XlsxAmount(this.value);
  final num value;
}

/// Builds the workbook bytes, ready for the [FileSaver] seam.
Uint8List buildXlsx(List<XlsxSheet> sheets) {
  final archive = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add('[Content_Types].xml', _contentTypes(sheets.length));
  add('_rels/.rels', _rootRels);
  add('xl/workbook.xml', _workbook(sheets));
  add('xl/_rels/workbook.xml.rels', _workbookRels(sheets.length));
  add('xl/styles.xml', _styles);
  for (var i = 0; i < sheets.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', _worksheet(sheets[i]));
  }

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _sheetName(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31);
}

/// A1-style column letters: 0 → A, 25 → Z, 26 → AA.
String _column(int index) {
  var i = index;
  var name = '';
  while (i >= 0) {
    name = String.fromCharCode(0x41 + (i % 26)) + name;
    i = i ~/ 26 - 1;
  }
  return name;
}

/// An absolute cell reference's marker (`$A$1`).
const _absolute = r'$';

// The cell styles of [_styles], by index.
const _header = 1;
const _dateTime = 2;
const _date = 3;
const _amount = 4;

/// Days since Excel's epoch (1899-12-30) at [d]'s wall-clock time.
num _serial(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second,
            d.millisecond)
        .difference(DateTime.utc(1899, 12, 30))
        .inMilliseconds /
    Duration.millisecondsPerDay;

String _text(String ref, String text, {int style = 0}) =>
    '<c r="$ref"${style == 0 ? '' : ' s="$style"'} t="inlineStr"><is>'
    '<t xml:space="preserve">${_escape(text)}</t></is></c>';

String _cell(String ref, Object? value) => switch (value) {
      null => '',
      final num n => '<c r="$ref"><v>$n</v></c>',
      final bool b => '<c r="$ref" t="b"><v>${b ? 1 : 0}</v></c>',
      final DateTime d => '<c r="$ref" s="$_dateTime"><v>${_serial(d)}</v></c>',
      final XlsxDate d => '<c r="$ref" s="$_date"><v>${_serial(d.value)}</v></c>',
      final XlsxAmount a => '<c r="$ref" s="$_amount"><v>${a.value}</v></c>',
      _ => _text(ref, value.toString()),
    };

/// How many characters a column needs: its widest cell, within reason.
double _width(List<List<Object?>> rows, int column) {
  var widest = 6;
  for (final row in rows) {
    if (column >= row.length) continue;
    final length = switch (row[column]) {
      null => 0,
      DateTime() => 16,
      XlsxDate() => 10,
      final XlsxAmount a => a.value.toStringAsFixed(2).length + 2,
      final Object v => v.toString().length,
    };
    if (length > widest) widest = length;
  }
  return (widest > 60 ? 60 : widest) + 2.0;
}

/// The cell range a sheet's filter covers: the header and every row.
String _range(XlsxSheet sheet) {
  final columns = sheet.rows.fold(0, (m, r) => r.length > m ? r.length : m);
  return 'A1:${_column(columns == 0 ? 0 : columns - 1)}${sheet.rows.length}';
}

String _worksheet(XlsxSheet sheet) {
  final rows = StringBuffer();
  for (var r = 0; r < sheet.rows.length; r++) {
    rows.write('<row r="${r + 1}">');
    final cells = sheet.rows[r];
    for (var c = 0; c < cells.length; c++) {
      final ref = '${_column(c)}${r + 1}';
      rows.write(r == 0 && cells[c] != null
          ? _text(ref, '${cells[c]}', style: _header)
          : _cell(ref, cells[c]));
    }
    rows.write('</row>');
  }
  final header = sheet.rows.isEmpty ? const <Object?>[] : sheet.rows.first;
  final cols = StringBuffer();
  for (var c = 0; c < header.length; c++) {
    cols.write('<col min="${c + 1}" max="${c + 1}" '
        'width="${_width(sheet.rows, c)}" customWidth="1"/>');
  }
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/'
      'spreadsheetml/2006/main">'
      '<sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" '
      'state="frozen"/></sheetView></sheetViews>'
      '${cols.isEmpty ? '' : '<cols>$cols</cols>'}'
      '<sheetData>$rows</sheetData>'
      '${header.isEmpty ? '' : '<autoFilter ref="${_range(sheet)}"/>'}'
      '</worksheet>';
}

String _workbook(List<XlsxSheet> sheets) {
  final entries = StringBuffer();
  final filters = StringBuffer();
  for (var i = 0; i < sheets.length; i++) {
    final name = _escape(_sheetName(sheets[i].name));
    entries.write('<sheet name="$name" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
    if (sheets[i].rows.isNotEmpty && sheets[i].rows.first.isNotEmpty) {
      // Excel keeps a sheet's filter range under this hidden name.
      final range = _range(sheets[i]).replaceAllMapped(
          RegExp(r'([A-Z]+)(\d+)'), (m) => '$_absolute${m[1]}$_absolute${m[2]}');
      filters.write('<definedName name="_xlnm._FilterDatabase" '
          'localSheetId="$i" hidden="1">'
          "'${name.replaceAll("'", "''")}'!$range</definedName>");
    }
  }
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/'
      'spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/'
      'relationships"><sheets>$entries</sheets>'
      '${filters.isEmpty ? '' : '<definedNames>$filters</definedNames>'}'
      '</workbook>';
}

String _workbookRels(int sheetCount) {
  final entries = StringBuffer();
  for (var i = 1; i <= sheetCount; i++) {
    entries.write('<Relationship Id="rId$i" Type="http://schemas.'
        'openxmlformats.org/officeDocument/2006/relationships/worksheet" '
        'Target="worksheets/sheet$i.xml"/>');
  }
  entries.write('<Relationship Id="rIdStyles" Type="http://schemas.'
      'openxmlformats.org/officeDocument/2006/relationships/styles" '
      'Target="styles.xml"/>');
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/'
      '2006/relationships">$entries</Relationships>';
}

String _contentTypes(int sheetCount) {
  final overrides = StringBuffer();
  for (var i = 1; i <= sheetCount; i++) {
    overrides.write('<Override PartName="/xl/worksheets/sheet$i.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.'
        'spreadsheetml.worksheet+xml"/>');
  }
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
      'content-types">'
      '<Default Extension="rels" ContentType="application/vnd.'
      'openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/'
      'vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.'
      'openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '$overrides</Types>';
}

const _rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
    'relationships"><Relationship Id="rId1" Type="http://schemas.'
    'openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
    'Target="xl/workbook.xml"/></Relationships>';

/// The styles: 0 plain, 1 the header (bold on a light fill), 2 a date and
/// time, 3 a date, 4 an amount with two decimals.
const _styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/'
    '2006/main">'
    '<numFmts count="2"><numFmt numFmtId="164" formatCode="yyyy-mm-dd hh:mm"/>'
    '<numFmt numFmtId="165" formatCode="yyyy-mm-dd"/></numFmts>'
    '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="3"><fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFE8EEF4"/>'
    '<bgColor indexed="64"/></patternFill></fill></fills>'
    '<borders count="1"><border/></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" '
    'borderId="0"/></cellStyleXfs>'
    '<cellXfs count="5">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" '
    'applyFont="1" applyFill="1"/>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1"/>'
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1"/>'
    '<xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/>'
    '</cellStyles></styleSheet>';
