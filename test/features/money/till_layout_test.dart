// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till layout's rules: a cell outside its grid, two cells on one place, a kind or function this app does not
// know, a tool smaller than it can be used at, an item the business does not sell, and the size cap are refused with
// where they are; every template is valid at the three sizes; the JSON round trip is stable and keeps a newer layout's
// unknown words.
import 'dart:convert';

import 'package:deskilo/features/money/domain/till_layout.dart';
import 'package:deskilo/features/money/domain/till_layout_templates.dart';
import 'package:flutter_test/flutter_test.dart';

const _cap = 200;

TillLayout _one(List<TillCell> cells, {int cols = 4, int rows = 4, String name = 'Front'}) => TillLayout(
  name: name,
  pages: [TillPage(name: 'Sale', grids: {TillLayoutSize.phone: TillGrid(cols: cols, rows: rows, cells: cells)})],
);

TillCell _item(String id, int col, int row) => TillCell(kindWire: TillWidgetKind.itemKey.wire, col: col, row: row, params: {'item_id': id});

List<TillLayoutProblemCode> _codes(TillLayout l, {Set<String>? items, int cap = _cap}) =>
    [for (final p in validateTillLayout(l, maxCells: cap, knownItems: items)) p.code];

String _named(TillTemplatePage p) => p.name;

void main() {
  test('a layout inside its grid, with no two cells on one place, is valid', () {
    final l = _one([_item('i1', 0, 0), _item('i2', 1, 0), TillCell(kindWire: TillWidgetKind.keypad.wire, col: 2, row: 0, colSpan: 2, rowSpan: 3)]);
    expect(_codes(l, items: {'i1', 'i2'}), isEmpty);
  });

  test('a cell past the edge, or with no span, is outside its grid, with where', () {
    final problems = validateTillLayout(_one([_item('i1', 3, 0).moved(colSpan: 2), _item('i1', 0, 0).moved(rowSpan: 0)]), maxCells: _cap);
    expect([for (final p in problems) p.code], [TillLayoutProblemCode.outsideGrid, TillLayoutProblemCode.outsideGrid]);
    expect(problems.first.page, 0);
    expect(problems.first.size, TillLayoutSize.phone);
    expect(problems.first.cell, 0);
  });

  test('two cells on one place overlap, the later one is named', () {
    final problems = validateTillLayout(_one([_item('i1', 0, 0).moved(colSpan: 2), _item('i2', 1, 0)]), maxCells: _cap);
    expect(problems.single.code, TillLayoutProblemCode.overlap);
    expect(problems.single.cell, 1);
  });

  test('a tool smaller than it is usable at is refused', () {
    expect(_codes(_one([TillCell(kindWire: TillWidgetKind.keypad.wire, col: 0, row: 0, colSpan: 2, rowSpan: 2)])), [TillLayoutProblemCode.tooSmall]);
  });

  test('a kind or a function this app does not know is refused, never guessed', () {
    expect(_codes(_one([const TillCell(kindWire: 'hologram', col: 0, row: 0)])), [TillLayoutProblemCode.unknownKind]);
    expect(
      _codes(_one([TillCell(kindWire: TillWidgetKind.functionKey.wire, col: 0, row: 0, params: const {'function': 'teleport'})])),
      [TillLayoutProblemCode.unknownFunction],
    );
  });

  test('an item key names an item of the business, or it is refused', () {
    expect(_codes(_one([_item('gone', 0, 0)]), items: {'i1'}), [TillLayoutProblemCode.unknownItem]);
    expect(_codes(_one([const TillCell(kindWire: 'item_key', col: 0, row: 0)]), items: {'i1'}), [TillLayoutProblemCode.unknownItem]);
  });

  test('the size cap counts every cell of every page and size', () {
    final l = _one([for (var i = 0; i < 4; i++) _item('i1', i, 0)]);
    expect(_codes(l, cap: 4), isEmpty);
    expect(_codes(l, cap: 3), [TillLayoutProblemCode.tooLarge]);
  });

  test('a layout needs a name, a page and a sensible grid', () {
    expect(_codes(_one(const [], name: ' ')), [TillLayoutProblemCode.noName]);
    expect(_codes(const TillLayout(name: 'x', pages: [])), [TillLayoutProblemCode.noPages]);
    expect(_codes(const TillLayout(name: 'x', pages: [TillPage(name: 'p', grids: {})])), [TillLayoutProblemCode.noGrid]);
    expect(_codes(_one(const [], cols: 0)), [TillLayoutProblemCode.badGrid]);
    expect(_codes(_one(const [], cols: tillLayoutMaxGridSide + 1)), [TillLayoutProblemCode.badGrid]);
  });

  for (final t in TillLayoutTemplate.values) {
    test('the ${t.wire} template is valid at the three sizes', () {
      final l = t.build('Till 1', pageName: _named);
      expect(_codes(l), isEmpty);
      for (final p in l.pages) {
        expect(p.grids.keys.toSet(), TillLayoutSize.values.toSet());
      }
      // every template can take the money and start the next sale
      final functions = {for (final p in l.pages) for (final g in p.grids.values) for (final c in g.cells) c.function};
      expect(functions, containsAll([TillFunction.payCash, TillFunction.nextCustomer]));
    });
  }

  test('the bakery template has the keypad, the hardware one the scan field first', () {
    Set<TillWidgetKind> kinds(TillLayoutTemplate t) =>
        {for (final c in t.build('x', pageName: _named).pages.first.grids[TillLayoutSize.desk]!.cells) c.kind};
    expect(kinds(TillLayoutTemplate.bakery), contains(TillWidgetKind.keypad));
    expect(kinds(TillLayoutTemplate.hardware), containsAll([TillWidgetKind.scanField, TillWidgetKind.keypad]));
    expect(kinds(TillLayoutTemplate.cafe), isNot(contains(TillWidgetKind.scanField)));
  });

  test('the JSON round trip is stable, and a newer layout keeps its unknown words', () {
    for (final t in TillLayoutTemplate.values) {
      final l = t.build('x', pageName: _named);
      final once = jsonEncode(l.toJson());
      final again = jsonEncode(TillLayout.fromJson(jsonDecode(once) as Map<String, Object?>, name: 'x').toJson());
      expect(again, once, reason: t.wire);
    }
    final newer = {
      'pages': [
        {
          'name': 'p',
          'grids': {
            'phone': {
              'cols': 2,
              'rows': 2,
              'cells': [
                {'kind': 'hologram', 'col': 0, 'row': 0, 'col_span': 1, 'row_span': 1, 'params': {'z': 1, 'a': 2}},
              ],
            },
            'watch': {'cols': 1, 'rows': 1, 'cells': <Object?>[]},
          },
        },
      ],
    };
    final read = TillLayout.fromJson(newer, name: 'n');
    final cell = read.pages.single.grids[TillLayoutSize.phone]!.cells.single;
    expect(cell.kind, TillWidgetKind.unknown);
    expect(cell.kindWire, 'hologram');
    expect(jsonEncode(read.toJson()), contains('"kind":"hologram"'));
    expect(jsonEncode(cell.toJson()['params']), '{"a":2,"z":1}');
    expect(read.pages.single.grids.keys, [TillLayoutSize.phone]);
  });

  test('a status from the future is never published', () {
    expect(TillLayoutStatus.of('published'), TillLayoutStatus.published);
    expect(TillLayoutStatus.of('archived'), TillLayoutStatus.unknown);
  });

  test('a window is laid out with the largest size it reaches', () {
    expect(TillLayoutSize.forWidth(390), TillLayoutSize.phone);
    expect(TillLayoutSize.forWidth(1000), TillLayoutSize.phone);
    expect(TillLayoutSize.forWidth(1024), TillLayoutSize.tablet);
    expect(TillLayoutSize.forWidth(1440), TillLayoutSize.desk);
    expect(TillLayoutSize.forWidth(2560), TillLayoutSize.desk);
  });
}
