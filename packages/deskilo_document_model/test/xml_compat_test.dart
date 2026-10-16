// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2592 C3 - older XML versions keep reading. Only version 1 exists today;
// when a newer one is added these fixtures must still parse and a change to
// their output is a format break.

import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:test/test.dart';

const _v1 = '''
<report-layout version="1" page="A4" margin="20mm">
  <header height="30mm"><text style="heading">Delivery note</text></header>
  <body>
    <table>
      <col w="70%"/><col w="30%" align="right"/>
      <row><cell>Item</cell><cell>Qty</cell></row>
    </table>
    <rule/>
  </body>
  <footer height="12mm"><text style="small">Thanks</text></footer>
</report-layout>
''';

void main() {
  test('a version-1 document reads and is written back as version 1', () {
    final doc = parseLayoutXml(_v1);
    expect(doc.body.children, hasLength(2));
    final out = layoutToXml(doc);
    expect(out, contains('version="${LayoutXml.version}"'));
    expect(layoutToXml(parseLayoutXml(out)), out);
  });

  test('a document without a version attribute is the first version', () {
    final legacy = _v1.replaceFirst('version="1" ', '');
    expect(
      layoutToXml(parseLayoutXml(legacy)),
      layoutToXml(parseLayoutXml(_v1)),
    );
  });

  test('the current version still accepts the version-1 fixture', () {
    expect(int.parse(LayoutXml.version), greaterThanOrEqualTo(1));
    expect(() => parseLayoutXml(_v1), returnsNormally);
  });

  test('a version this reader does not know is refused, not guessed', () {
    final future = _v1.replaceFirst('version="1"', 'version="99"');
    expect(
      () => parseLayoutXml(future),
      throwsA(
        isA<LayoutException>().having(
          (e) => e.error,
          'error',
          LayoutError.unsupportedVersion,
        ),
      ),
    );
  });
}
