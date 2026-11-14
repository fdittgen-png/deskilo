// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3852 — a document is printed on the paper it is given: A4 unless named,
// Letter when named. A4 keeps every byte it had; on Letter a long
// positioned invoice flows in the Letter sheet, with no ink off the page
// and no row under the footer.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_conformance.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/pdf_geometry.dart';

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

const _layout = '''
<report-layout margin="20mm">
  <header height="25mm">
    <text style="heading">{{ workspace }}</text>
  </header>
  <continuation height="8mm">
    <text style="small">{{ workspace }} · {{ number }}</text>
  </continuation>
  <body>
    <text style="subheading">INVOICE {{ number }}</text>
    <table>
      <col w="60%"/><col w="40%" align="right"/>
      {% for line in lines %}<row><cell>{{ line.label }}</cell><cell>{{ line.amount }}</cell></row>
      {% endfor %}
    </table>
  </body>
  <footer height="20mm">
    <text style="small">FOOTER</text>
  </footer>
</report-layout>
''';

Map<String, Object?> _data(int lines) => {
  'workspace': 'COWORKONTI',
  'number': 'INV-2026-0050',
  'lines': [
    for (var i = 0; i < lines; i++)
      {'label': 'Desk, half day $i', 'amount': '25.00'},
  ],
};

Future<Uint8List> _positioned(int lines, {Paper? paper}) {
  final data = _data(lines);
  final made = renderLayoutDocument(_layout, data);
  return buildLayoutPdf(
    document: paper == null ? made : made.onPaper(paper),
    data: data,
    documentTitle: 'test',
    pageLabel: 'Page',
    baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
    boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
  );
}

/// The sizes of the pages, in points.
List<(double, double)> _mediaBoxes(Uint8List bytes) => [
  for (final m in RegExp(
    r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]',
  ).allMatches(latin1.decode(bytes)))
    (double.parse(m.group(1)!), double.parse(m.group(2)!)),
];

/// The bytes without what changes on every run: the id and the dates.
String _stable(Uint8List bytes) => latin1
    .decode(bytes)
    .replaceAll(RegExp(r'/ID\s*\[[^\]]*\]'), '')
    .replaceAll(RegExp(r'/(CreationDate|ModDate)\s*\([^)]*\)'), '');

void main() {
  test('the two papers and their wire words', () {
    expect(Paper.fromWire('A4'), Paper.a4);
    expect(Paper.fromWire('Letter'), Paper.letter);
    expect(Paper.fromWire('Legal'), isNull);
    expect(Paper.fromWire(null), isNull);
    expect(LayoutDocument.pageFormats, ['A4', 'Letter']);
  });

  test('a layout made on Letter is read; another paper is refused', () {
    expect(
      parseLayoutXml('<report-layout page="Letter"/>').paper,
      Paper.letter,
    );
    expect(parseLayoutXml('<report-layout/>').paper, Paper.a4);
    expect(
      () => parseLayoutXml('<report-layout page="Legal"/>'),
      throwsA(
        isA<LayoutException>()
            .having((e) => e.error, 'error', LayoutError.badAttribute)
            .having((e) => e.toString(), 'text', contains('A4, Letter')),
      ),
    );
  });

  test('A4 unless named, with the same bytes', () async {
    // a design made on A4 printed on A4 is the design as it was
    final unnamed = await _positioned(3);
    final named = await _positioned(3, paper: Paper.a4);
    expect(_stable(named), _stable(unnamed));
    expect(_mediaBoxes(unnamed).single.$2, closeTo(841.89, 0.01));
  });

  test('a long positioned invoice flows on Letter, inside the sheet', () async {
    final a4 = await _positioned(120);
    final letter = await _positioned(120, paper: Paper.letter);
    final sheets = _mediaBoxes(letter);
    expect(sheets.length, greaterThan(1));
    for (final (w, h) in sheets) {
      expect((w, h), (612.0, 792.0));
    }
    // a shorter sheet holds fewer rows
    expect(sheets.length, greaterThanOrEqualTo(_mediaBoxes(a4).length));
    final ink = textPositions(letter, paper: Paper.letter);
    expect(ink.map((i) => i.page).toSet().length, sheets.length);
    const bottomMarginMm = 20.0;
    for (final i in ink) {
      expect(i.xMm, inInclusiveRange(0, Paper.letter.widthMm), reason: '$i');
      expect(
        i.yMm,
        inInclusiveRange(0, Paper.letter.heightMm - bottomMarginMm + 1),
        reason: '$i: no ink in the bottom margin, none off the sheet',
      );
    }
  });

  test('a banded letter is printed on the paper it is given', () async {
    Future<Uint8List> letter({Paper paper = Paper.a4}) => buildBandedLetterPdf(
      report: InvoiceReport(
        header: const [ReportHeading('HEADER')],
        body: [for (var i = 0; i < 90; i++) ReportText('Row $i')],
        footer: const [ReportText('FOOTER')],
        paper: paper,
      ),
      pageLabel: 'Page',
      documentTitle: 'Reminder',
      baseFont: pw.Font.helvetica(),
      boldFont: pw.Font.helveticaBold(),
    );
    for (final (w, h) in _mediaBoxes(await letter(paper: Paper.letter))) {
      expect((w, h), (612.0, 792.0));
    }
    expect(_mediaBoxes(await letter()).first.$1, closeTo(595.28, 0.01));
  });

  test('the envelope zones end at the bottom margin of the paper', () {
    double bodyEnd(Paper paper) => reportZones(
      AddressWindow.off,
      paper: paper,
    ).firstWhere((z) => z.name == 'body').bottomMm;
    expect(bodyEnd(Paper.a4), closeTo(277, 0.001));
    expect(bodyEnd(Paper.letter), closeTo(259.4, 0.001));
    expect(
      reportZones(AddressWindow.off).last.bottomMm,
      bodyEnd(Paper.a4),
      reason: 'A4 unless named',
    );
  });
}
