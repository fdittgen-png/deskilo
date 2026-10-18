// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2589 C2 -- the layout model is a value: a list handed to a constructor is
// copied, the list the model exposes cannot be changed, nested lists
// included, and a caller that keeps and edits its own list changes nothing
// in a document already built.
import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:test/test.dart';

void main() {
  test('a row, a table, a box, columns and a zone refuse mutation', () {
    final row = LayoutRow([const LayoutCell('a')]);
    final table = LayoutTable(columns: [const LayoutColumn()], rows: [row]);
    final box = LayoutBox([LayoutText('x'), table]);
    final columns = LayoutColumns([
      [LayoutText('left')],
      [LayoutText('right')],
    ]);
    final zone = LayoutZone(children: [box, columns]);

    expect(() => row.cells.add(const LayoutCell('b')), throwsUnsupportedError);
    expect(() => table.rows.clear(), throwsUnsupportedError);
    expect(() => table.columns.add(const LayoutColumn()), throwsUnsupportedError);
    expect(() => box.children.removeLast(), throwsUnsupportedError);
    expect(() => columns.columns.add([]), throwsUnsupportedError);
    expect(() => columns.columns.first.add(LayoutText('y')), throwsUnsupportedError,
        reason: 'the nested column list is frozen too');
    expect(() => zone.children.add(LayoutRule()), throwsUnsupportedError);
  });

  test('editing the list a caller kept does not change the document', () {
    final cells = [const LayoutCell('a')];
    final kids = <LayoutElement>[LayoutText('x')];
    final left = <LayoutElement>[LayoutText('l')];
    final row = LayoutRow(cells);
    final box = LayoutBox(kids);
    final columns = LayoutColumns([left]);
    final zone = LayoutZone(children: kids);

    cells.add(const LayoutCell('b'));
    kids.add(LayoutRule());
    left.add(LayoutRule());

    expect(row.cells, hasLength(1));
    expect(box.children, hasLength(1));
    expect(columns.columns.single, hasLength(1));
    expect(zone.children, hasLength(1));
  });

  test('the default zones are empty and the defaults are not shared mutable lists', () {
    final doc = LayoutDocument();
    expect(doc.header.isEmpty, isTrue);
    expect(doc.body.children, isEmpty);
    expect(() => doc.body.children.add(LayoutRule()), throwsUnsupportedError);
    expect(identical(doc.header, LayoutZone.empty), isTrue);
  });

  test('a design read from XML is frozen all the way down', () {
    final doc = parseLayoutXml('''
<report-layout version="1">
  <body>
    <table>
      <col w="100%"/>
      <row><cell>a</cell></row>
    </table>
  </body>
</report-layout>''');
    final table = doc.body.children.whereType<LayoutTable>().single;
    expect(() => table.rows.add(LayoutRow(const [])), throwsUnsupportedError);
    expect(() => table.rows.first.cells.add(const LayoutCell('z')), throwsUnsupportedError);
    expect(() => doc.body.children.clear(), throwsUnsupportedError);
  });
}
