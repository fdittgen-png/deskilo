// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2592 - the document model used by a host that is not Deskilo: a
// delivery note written as XML, read back, written, bounded.

import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:test/test.dart';

const _note = '''
<report-layout version="1">
  <header height="30mm"><text style="heading">Delivery note</text></header>
  <body>
    <table>
      <col w="70%"/><col w="30%" align="right"/>
      <row><cell>Item</cell><cell>Qty</cell></row>
      <row bold="true"><cell>Pallet</cell><cell>3</cell></row>
    </table>
    <rule/>
    <text>Signed &amp; received</text>
  </body>
  <footer height="12mm"><text style="small">Thank you</text></footer>
</report-layout>
''';

void main() {
  test('a delivery note reads, writes and reads back to the same tree', () {
    final first = parseLayoutXml(_note);
    expect(first.body.children, hasLength(3));
    final again = parseLayoutXml(layoutToXml(first));
    expect(layoutToXml(again), layoutToXml(first));
  });

  test('an element the vocabulary lacks is a typed error, not a skip', () {
    expect(
      () => parseLayoutXml(
        '<report-layout version="1"><body><script/></body></report-layout>',
      ),
      throwsA(
        isA<LayoutException>().having(
          (e) => e.error,
          'error',
          LayoutError.unknownElement,
        ),
      ),
    );
  });

  test('an unsupported version and an unknown unit are refused', () {
    expect(
      () => parseLayoutXml('<report-layout version="9"/>'),
      throwsA(isA<LayoutException>()),
    );
    expect(() => Length.parse('3furlong'), throwsA(isA<LayoutException>()));
  });

  test('text is text: markup in a value cannot become layout', () {
    final doc = LayoutDocument(
      body: LayoutZone(children: [const LayoutText('<rule/> & <spacer/>')]),
    );
    final back = parseLayoutXml(layoutToXml(doc));
    expect(back.body.children, hasLength(1));
    expect(
      (back.body.children.single as LayoutText).text,
      '<rule/> & <spacer/>',
    );
  });

  test('malformed and excessive input fails with a typed error', () {
    expect(
      () => parseLayoutXml('<report-layout'),
      throwsA(isA<LayoutException>()),
    );
    final deep = '<box>' * 3000 + '</box>' * 3000;
    expect(
      () => parseLayoutXml(
        '<report-layout version="1"><body>$deep</body></report-layout>',
      ),
      throwsA(isA<LayoutException>()),
    );
  });
}
