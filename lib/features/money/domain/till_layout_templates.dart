// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the layouts a till starts from, one per trade. They place the tools and function keys; the owner adds the item
// keys of the business (a template names no item, so it fits every business). Each is valid at the three sizes.
import 'till_layout.dart';

/// The trades a layout starts from.
enum TillLayoutTemplate {
  /// The #4366 default: scan, basket, total, the pay and next keys.
  retail('retail'),

  /// Weighed goods: a keypad beside large keys, the total in view.
  bakery('bakery'),

  /// Category pages, no scan field.
  cafe('cafe'),

  /// Passes and sessions at the studio desk.
  studio('studio'),

  /// Catalogue goods: the scan field and the keypad first.
  hardware('hardware');

  const TillLayoutTemplate(this.wire);

  final String wire;

  /// The layout this template starts, named [name]; its pages are named by [pageName] in the reader's language.
  TillLayout build(String name, {required String Function(TillTemplatePage) pageName}) => TillLayout(name: name, pages: switch (this) {
    TillLayoutTemplate.retail => [_page(pageName(TillTemplatePage.sale), _retail)],
    TillLayoutTemplate.bakery => [_page(pageName(TillTemplatePage.sale), _bakery)],
    TillLayoutTemplate.cafe => [_page(pageName(TillTemplatePage.drinks), _cafe), _page(pageName(TillTemplatePage.food), _cafe)],
    TillLayoutTemplate.studio => [_page(pageName(TillTemplatePage.desk), _studio)],
    TillLayoutTemplate.hardware => [_page(pageName(TillTemplatePage.sale), _hardware)],
  });
}

/// The pages a template starts with, named in the reader's language when it is built.
enum TillTemplatePage { sale, drinks, food, desk }

typedef _Place = List<TillCell> Function(int cols, int rows);

/// The grid side of each size: the phone is narrow and tall, the desk wide.
const Map<TillLayoutSize, (int, int)> _grid = {
  TillLayoutSize.phone: (4, 8),
  TillLayoutSize.tablet: (8, 6),
  TillLayoutSize.desk: (12, 6),
};

TillPage _page(String name, _Place place) => TillPage(
  name: name,
  grids: {
    for (final e in _grid.entries) e.key: TillGrid(cols: e.value.$1, rows: e.value.$2, cells: place(e.value.$1, e.value.$2)),
  },
);

TillCell _tool(TillWidgetKind kind, int col, int row, int cs, int rs) => TillCell(kindWire: kind.wire, col: col, row: row, colSpan: cs, rowSpan: rs);
TillCell _fn(TillFunction f, int col, int row, [int cs = 1]) =>
    TillCell(kindWire: TillWidgetKind.functionKey.wire, col: col, row: row, colSpan: cs, params: {tillCellFunctionParam: f.wire});

/// The basket on the left half, the total under it, the pay and next keys on the bottom row.
List<TillCell> _payRow(int cols, int rows) => [
  _tool(TillWidgetKind.basket, 0, 0, cols ~/ 2, rows - 2),
  _tool(TillWidgetKind.totalDisplay, 0, rows - 2, cols ~/ 2, 1),
  _fn(TillFunction.payCash, 0, rows - 1, cols ~/ 4),
  _fn(TillFunction.payCard, cols ~/ 4, rows - 1, cols ~/ 4),
  _fn(TillFunction.nextCustomer, cols ~/ 2, rows - 1, cols - cols ~/ 2),
];

List<TillCell> _retail(int cols, int rows) => [
  ..._payRow(cols, rows),
  _tool(TillWidgetKind.scanField, cols ~/ 2, 0, cols - cols ~/ 2, 1),
];

/// The keypad takes half of the right side (at least its own width), so a calculator fits beside it on the larger grids.
List<TillCell> _bakery(int cols, int rows) => [
  ..._payRow(cols, rows),
  _tool(TillWidgetKind.keypad, cols ~/ 2, 0, (cols - cols ~/ 2) ~/ 2 < 2 ? 2 : (cols - cols ~/ 2) ~/ 2, 3),
  _fn(TillFunction.quantityTimes, cols ~/ 2, 3),
];

List<TillCell> _cafe(int cols, int rows) => [
  ..._payRow(cols, rows),
  _tool(TillWidgetKind.cashNotes, cols ~/ 2, rows - 2, cols - cols ~/ 2, 1),
];

List<TillCell> _studio(int cols, int rows) => [
  ..._payRow(cols, rows),
  _tool(TillWidgetKind.studioPasses, cols ~/ 2, 0, cols - cols ~/ 2, 2),
  _tool(TillWidgetKind.customerNote, cols ~/ 2, 2, cols - cols ~/ 2, 1),
];

List<TillCell> _hardware(int cols, int rows) => [
  ..._payRow(cols, rows),
  _tool(TillWidgetKind.scanField, cols ~/ 2, 0, cols - cols ~/ 2, 1),
  _tool(TillWidgetKind.keypad, cols ~/ 2, 1, cols - cols ~/ 2, 3),
];
