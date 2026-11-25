// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- what the layout editor does to a grid, without dragging: add a widget at the first free place it fits, move a
// cell one step, make it one column or row larger or smaller, remove it. Every edit answers the new grid, or null when
// the step would leave the grid, shrink below the kind's span or lie on another cell -- the editor then disables that
// button, so a drag and its accessible twin cannot make a layout the server refuses.
import 'till_layout.dart';

/// One step of a cell on its grid.
enum TillCellStep { left, right, up, down, wider, narrower, taller, shorter }

/// [g] with a [kind] cell of its smallest span at the first free place, reading row by row; null when none is free.
TillGrid? addCell(TillGrid g, TillWidgetKind kind, {Map<String, Object?> params = const {}}) {
  for (var row = 0; row + kind.minRows <= g.rows; row++) {
    for (var col = 0; col + kind.minCols <= g.cols; col++) {
      final cell = TillCell(kindWire: kind.wire, col: col, row: row, colSpan: kind.minCols, rowSpan: kind.minRows, params: params);
      if (_fits(g, cell, except: -1)) return g.withCells([...g.cells, cell]);
    }
  }
  return null;
}

/// [g] with cell [index] moved or resized by [step]; null when the result would not fit.
TillGrid? stepCell(TillGrid g, int index, TillCellStep step) {
  final c = g.cells[index];
  final next = switch (step) {
    TillCellStep.left => c.moved(col: c.col - 1),
    TillCellStep.right => c.moved(col: c.col + 1),
    TillCellStep.up => c.moved(row: c.row - 1),
    TillCellStep.down => c.moved(row: c.row + 1),
    TillCellStep.wider => c.moved(colSpan: c.colSpan + 1),
    TillCellStep.narrower => c.moved(colSpan: c.colSpan - 1),
    TillCellStep.taller => c.moved(rowSpan: c.rowSpan + 1),
    TillCellStep.shorter => c.moved(rowSpan: c.rowSpan - 1),
  };
  if (next.colSpan < c.kind.minCols || next.rowSpan < c.kind.minRows || !_fits(g, next, except: index)) return null;
  return g.withCells([...g.cells.take(index), next, ...g.cells.skip(index + 1)]);
}

/// [g] without cell [index].
TillGrid removeCell(TillGrid g, int index) => g.withCells([for (var i = 0; i < g.cells.length; i++) if (i != index) g.cells[i]]);

bool _fits(TillGrid g, TillCell c, {required int except}) {
  if (c.col < 0 || c.row < 0 || c.col + c.colSpan > g.cols || c.row + c.rowSpan > g.rows) return false;
  for (var i = 0; i < g.cells.length; i++) {
    if (i != except && g.cells[i].overlaps(c)) return false;
  }
  return true;
}
