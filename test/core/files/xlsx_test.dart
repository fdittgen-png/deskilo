// SPDX-License-Identifier: 0BSD
//
// The XLSX writer (#395) is proven by UNZIPPING its own output — the same
// bar a spreadsheet reader applies — not by trusting the strings it was
// built from.

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:deskilo/core/files/xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

Archive _unzip(List<int> bytes) => ZipDecoder().decodeBytes(bytes);

String _part(Archive archive, String path) {
  final file = archive.findFile(path);
  expect(file, isNotNull, reason: 'workbook part missing: $path');
  return utf8.decode(file!.content as List<int>);
}

void main() {
  final bytes = buildXlsx([
    XlsxSheet(name: 'Reservations', rows: [
      ['id', 'member', 'amount', 'starts_at', 'attended'],
      ['res-1', 'Flo & Co <3', 42.5, DateTime.utc(2026, 5, 13, 9), true],
    ]),
    const XlsxSheet(name: 'A[very]:long*sheet?name/that\\overflows31',
        rows: [
          ['only']
        ]),
  ]);

  test('the output is a real ZIP carrying every required workbook part',
      () {
    // PK magic first — a spreadsheet reader checks nothing else before
    // giving up.
    expect(bytes.sublist(0, 2), [0x50, 0x4B]);
    final archive = _unzip(bytes);
    for (final part in [
      '[Content_Types].xml',
      '_rels/.rels',
      'xl/workbook.xml',
      'xl/_rels/workbook.xml.rels',
      'xl/styles.xml',
      'xl/worksheets/sheet1.xml',
      'xl/worksheets/sheet2.xml',
    ]) {
      expect(archive.findFile(part), isNotNull, reason: 'missing $part');
    }
  });

  test('cells round-trip: text is XML-escaped, numbers stay numeric, '
      'dates are ISO text', () {
    final sheet = _part(_unzip(bytes), 'xl/worksheets/sheet1.xml');
    expect(sheet, contains('Flo &amp; Co &lt;3'),
        reason: 'unescaped & or < breaks the whole part');
    expect(sheet, contains('<c r="C2"><v>42.5</v></c>'),
        reason: 'numbers must be native cells so Excel can sum them');
    expect(sheet, contains('2026-05-13T09:00:00.000Z'));
    expect(sheet, contains('TRUE'));
  });

  test('sheet names are sanitised to what Excel accepts — forbidden '
      'characters and the 31-char cap would make the file unopenable',
      () {
    final workbook = _part(_unzip(bytes), 'xl/workbook.xml');
    expect(workbook, contains('name="Reservations"'));
    final name = RegExp('name="([^"]+)" sheetId="2"')
        .firstMatch(workbook)!
        .group(1)!;
    expect(name.length, lessThanOrEqualTo(31));
    expect(name, isNot(matches(RegExp(r'[\[\]:*?/\\]'))));
  });

  test('every sheet is declared in the content types and wired through '
      'the workbook relationships', () {
    final archive = _unzip(bytes);
    final types = _part(archive, '[Content_Types].xml');
    expect(types, contains('/xl/worksheets/sheet2.xml'));
    final rels = _part(archive, 'xl/_rels/workbook.xml.rels');
    expect(rels, contains('Target="worksheets/sheet2.xml"'));
  });
}
