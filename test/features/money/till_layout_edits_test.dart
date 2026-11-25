// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the editor's steps without dragging: a widget is added at the first free place it fits, a cell moves and
// resizes one step at a time, and no step leaves the grid, shrinks below the kind's span or lies on another cell; every
// grid the steps make passes the layout's own validation.
import 'package:deskilo/features/money/domain/till_layout.dart';
import 'package:deskilo/features/money/domain/till_layout_edits.dart';
import 'package:flutter_test/flutter_test.dart';

TillLayout _layout(TillGrid g) => TillLayout(name: 'x', pages: [TillPage(name: 'p', grids: {TillLayoutSize.phone: g})]);

void main() {
  test('a widget is added at the first free place, row by row, at its smallest span', () {
    var g = const TillGrid(cols: 4, rows: 4);
    g = addCell(g, TillWidgetKind.basket)!;
    g = addCell(g, TillWidgetKind.keypad)!;
    expect([for (final c in g.cells) '${c.col},${c.row} ${c.colSpan}x${c.rowSpan}'], ['0,0 2x2', '2,0 2x3']);
    expect(validateTillLayout(_layout(g), maxCells: 200), isEmpty);
  });

  test('a widget that fits nowhere is not added', () {
    final g = addCell(const TillGrid(cols: 2, rows: 2), TillWidgetKind.keypad);
    expect(g, isNull);
  });

  test('a cell moves and resizes one step, and never off the grid, below its span or onto another cell', () {
    var g = addCell(const TillGrid(cols: 4, rows: 4), TillWidgetKind.basket)!;
    expect(stepCell(g, 0, TillCellStep.left), isNull, reason: 'off the left edge');
    expect(stepCell(g, 0, TillCellStep.narrower), isNull, reason: 'below the basket span');
    g = stepCell(g, 0, TillCellStep.right)!;
    g = stepCell(g, 0, TillCellStep.down)!;
    g = stepCell(g, 0, TillCellStep.wider)!;
    expect('${g.cells[0].col},${g.cells[0].row} ${g.cells[0].colSpan}x${g.cells[0].rowSpan}', '1,1 3x2');
    expect(stepCell(g, 0, TillCellStep.wider), isNull, reason: 'past the right edge');
    g = addCell(g, TillWidgetKind.itemKey, params: const {'item_id': 'i1'})!;
    expect('${g.cells[1].col},${g.cells[1].row}', '0,0');
    g = stepCell(g, 1, TillCellStep.right)!;
    expect(stepCell(g, 1, TillCellStep.down), isNull, reason: 'onto the basket at 1,1');
    expect(validateTillLayout(_layout(g), maxCells: 200), isEmpty);
  });

  test('a removed cell frees its place', () {
    var g = addCell(const TillGrid(cols: 2, rows: 2), TillWidgetKind.basket)!;
    expect(addCell(g, TillWidgetKind.itemKey), isNull);
    g = removeCell(g, 0);
    expect(g.cells, isEmpty);
    expect(addCell(g, TillWidgetKind.itemKey), isNotNull);
  });
}
