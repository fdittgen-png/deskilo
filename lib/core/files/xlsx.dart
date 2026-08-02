// SPDX-License-Identifier: 0BSD
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
/// as text. Dates are written as ISO-8601 text rather than Excel date
/// serials — unambiguous in every locale and timezone, which for a
/// bookkeeping export beats double-click formatting.
class XlsxSheet {
  const XlsxSheet({required this.name, required this.rows});

  /// Tab name. Sanitised on write: Excel refuses names longer than 31
  /// chars or containing []:*?/\ — silently producing an unopenable file
  /// otherwise.
  final String name;

  /// First row is the header. Cells: String, num, bool, DateTime or null.
  final List<List<Object?>> rows;
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

String _cell(String ref, Object? value) => switch (value) {
      null => '',
      num n => '<c r="$ref"><v>$n</v></c>',
      bool b => '<c r="$ref" t="inlineStr"><is><t>${b ? 'TRUE' : 'FALSE'}'
          '</t></is></c>',
      DateTime d => '<c r="$ref" t="inlineStr"><is><t>'
          '${d.toIso8601String()}</t></is></c>',
      _ => '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
          '${_escape(value.toString())}</t></is></c>',
    };

String _worksheet(XlsxSheet sheet) {
  final rows = StringBuffer();
  for (var r = 0; r < sheet.rows.length; r++) {
    rows.write('<row r="${r + 1}">');
    final cells = sheet.rows[r];
    for (var c = 0; c < cells.length; c++) {
      rows.write(_cell('${_column(c)}${r + 1}', cells[c]));
    }
    rows.write('</row>');
  }
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/'
      'spreadsheetml/2006/main">'
      '<sheetData>$rows</sheetData></worksheet>';
}

String _workbook(List<XlsxSheet> sheets) {
  final entries = StringBuffer();
  for (var i = 0; i < sheets.length; i++) {
    entries.write('<sheet name="${_escape(_sheetName(sheets[i].name))}" '
        'sheetId="${i + 1}" r:id="rId${i + 1}"/>');
  }
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/'
      'spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/'
      'relationships"><sheets>$entries</sheets></workbook>';
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

/// The smallest styles part strict readers accept.
const _styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/'
    '2006/main"><fonts count="1"><font><sz val="11"/><name val="Calibri"/>'
    '</font></fonts><fills count="1"><fill><patternFill patternType="none"/>'
    '</fill></fills><borders count="1"><border/></borders>'
    '<cellStyleXfs count="1"><xf/></cellStyleXfs>'
    '<cellXfs count="1"><xf/></cellXfs></styleSheet>';
