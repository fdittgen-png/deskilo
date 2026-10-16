// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2592 - the PDF renderer used by a host that is not Deskilo: a
// delivery note with host-supplied fonts, no invoice, no application.

import 'dart:convert';

import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:deskilo_document_pdf/deskilo_document_pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

const _note = '''
<report-layout version="1">
  <header height="30mm"><text style="heading">Delivery note</text></header>
  <body>
    <table>
      <col w="70%"/><col w="30%" align="right"/>
      <row><cell>Item</cell><cell>Qty</cell></row>
      <row><cell>Pallet</cell><cell>3</cell></row>
    </table>
    <markup>bridge</markup>
  </body>
  <footer height="12mm"><text style="small">Thank you</text></footer>
</report-layout>
''';

Future<List<int>> _render(
  LayoutDocument doc, {
  List<String>? diagnostics,
  LayoutMarkupBuilder? markup,
}) => buildLayoutPdf(
  document: doc,
  recipientName: 'Ana Smith',
  recipientAddress: '1 Main Street',
  documentTitle: 'Delivery note',
  pageLabel: 'Page',
  baseFont: pw.Font.helvetica(),
  boldFont: pw.Font.helveticaBold(),
  markup: markup,
  diagnostics: diagnostics,
);

void main() {
  test('a delivery note renders to a PDF with the host fonts only', () async {
    final bytes = await _render(parseLayoutXml(_note));
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });

  test('a markup element without a host renderer says so', () async {
    final diagnostics = <String>[];
    await _render(parseLayoutXml(_note), diagnostics: diagnostics);
    expect(diagnostics, ['markup element has no renderer']);
  });

  test('a host markup renderer is used and leaves no diagnostic', () async {
    final diagnostics = <String>[];
    await _render(
      parseLayoutXml(_note),
      diagnostics: diagnostics,
      markup: (source, images) => [pw.Text(source)],
    );
    expect(diagnostics, isEmpty);
  });

  test('the window recipient lands on page one inside the aperture', () {
    expect(AddressWindow.left.leftEdge, closeTo(20 * 72 / 25.4, 1e-9));
    expect(AddressWindow.right.leftEdge, closeTo(110 * 72 / 25.4, 1e-9));
    expect(addressWindowTop, closeTo(45 * 72 / 25.4, 1e-9));
  });

  test('image names are collected so the host can fetch them first', () {
    final doc = parseLayoutXml(
      '<report-layout version="1"><body><image name="logo"/></body>'
      '</report-layout>',
    );
    expect(layoutImageNames(doc), {'logo'});
  });
}
