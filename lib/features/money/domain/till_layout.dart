// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- a till's layout: the pages (tabs) of a till, each a grid for three screen sizes, each cell one widget from the
// catalogue with its span. The layout only arranges what the till already does (#4366, #4185): a key calls an existing
// command, a tool is an existing panel. A till without a layout keeps the generated one of #4366.
//
// The server (till_layout_save_v1) validates the same rules as [validateTillLayout]; the Demo's store runs this one.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:meta/meta.dart';

/// The three sizes a till is laid out for, by the width it is drawn at.
enum TillLayoutSize {
  phone('phone', 390),
  tablet('tablet', 1024),
  desk('desk', 1440);

  const TillLayoutSize(this.wire, this.width);

  final String wire;

  /// The width this size stands for, in logical pixels.
  final double width;

  /// The size a window of [width] is laid out with: the largest one it reaches.
  static TillLayoutSize forWidth(double width) => width >= desk.width
      ? desk
      : width >= tablet.width
      ? tablet
      : phone;

  static TillLayoutSize? of(String wire) => values.where((s) => s.wire == wire).firstOrNull;
}

/// What a cell holds: a key or a tool. [minCols] x [minRows] is the smallest span it is usable at.
enum TillWidgetKind {
  itemKey('item_key', 1, 1),
  categoryKey('category_key', 1, 1),
  functionKey('function_key', 1, 1),
  keypad('keypad', 2, 3),
  calculator('calculator', 2, 3),
  scanField('scan_field', 2, 1),
  basket('basket', 2, 2),
  totalDisplay('total_display', 2, 1),
  customerNote('customer_note', 2, 1),
  studioPasses('studio_passes', 2, 2),
  cashNotes('cash_notes', 2, 1),

  /// A kind this app does not know (a newer layout): kept with its raw word, drawn as nothing usable, never saved as valid.
  unknown('', 1, 1);

  const TillWidgetKind(this.wire, this.minCols, this.minRows);

  final String wire;
  final int minCols;
  final int minRows;

  static TillWidgetKind of(String wire) => values.firstWhere((k) => k.wire == wire && k != unknown, orElse: () => unknown);
}

/// What a function key does: each one an existing till command.
enum TillFunction {
  payCash('pay_cash'),
  payCard('pay_card'),
  nextCustomer('next_customer'),
  voidLine('void_line'),
  lineDiscount('line_discount'),
  quantityTimes('quantity_times'),
  priceOverride('price_override'),
  depositReturn('deposit_return'),
  openDrawer('open_drawer'),
  reprintLast('reprint_last'),

  /// A function this app does not know: the key is shown disabled with its raw word.
  unknown('');

  const TillFunction(this.wire);

  final String wire;

  static TillFunction of(String wire) => values.firstWhere((f) => f.wire == wire && f != unknown, orElse: () => unknown);
}

/// Whether a layout is still being edited or is the one the till uses.
enum TillLayoutStatus {
  draft('draft'),
  published('published'),

  /// A status this app does not know: never treated as published.
  unknown('');

  const TillLayoutStatus(this.wire);

  final String wire;

  static TillLayoutStatus of(String wire) => values.firstWhere((s) => s.wire == wire && s != unknown, orElse: () => unknown);
}

/// The parameter of an item key naming what it sells, and of a function key naming what it runs: the layout format's
/// own words, the same in till_layout_problems.
const _itemParam = 'item_id';
const _labelParam = 'label';
const _pageParam = 'page';

/// The parameters of a category key opening page [page] (from 0), shown as [label].
Map<String, Object?> tillCategoryKeyParams(int page, String label) => {_pageParam: page, _labelParam: label};

/// The parameters of an item key selling [itemId], shown as [label] until the till reads the item's own name.
Map<String, Object?> tillItemKeyParams(String itemId, String label) => {_itemParam: itemId, _labelParam: label};
const tillCellFunctionParam = 'function';

/// One widget placed on a grid: its column and row (from 0), its span, and its parameters (an item key's item id, a
/// function key's function, a category key's group or page, a label, a colour, a fixed quantity).
class TillCell {
  const TillCell({required this.kindWire, required this.col, required this.row, this.colSpan = 1, this.rowSpan = 1, this.params = const {}});

  /// The kind as written: an unknown word is kept, so a newer layout survives a round trip through this app.
  final String kindWire;
  final int col;
  final int row;
  final int colSpan;
  final int rowSpan;
  final Map<String, Object?> params;

  TillWidgetKind get kind => TillWidgetKind.of(kindWire);

  /// The item, service or variant an item key sells; null for any other kind.
  String? get itemId => kind == TillWidgetKind.itemKey ? params[_itemParam] as String? : null;

  /// The page a category key opens (from 0); null for any other kind or a key that names none.
  int? get targetPage => kind == TillWidgetKind.categoryKey && params[_pageParam] is int ? params[_pageParam] as int : null;

  /// The label written on a key when it was placed, or empty.
  String get label => '${params[_labelParam] ?? ''}';

  /// The function a function key runs; null for any other kind.
  TillFunction? get function => kind == TillWidgetKind.functionKey ? TillFunction.of('${params[tillCellFunctionParam] ?? ''}') : null;

  bool overlaps(TillCell o) => col < o.col + o.colSpan && o.col < col + colSpan && row < o.row + o.rowSpan && o.row < row + rowSpan;

  TillCell moved({int? col, int? row, int? colSpan, int? rowSpan}) => TillCell(
    kindWire: kindWire,
    col: col ?? this.col,
    row: row ?? this.row,
    colSpan: colSpan ?? this.colSpan,
    rowSpan: rowSpan ?? this.rowSpan,
    params: params,
  );

  Map<String, Object?> toJson() => {
    'kind': kindWire,
    'col': col,
    'row': row,
    'col_span': colSpan,
    'row_span': rowSpan,
    if (params.isNotEmpty) 'params': {for (final k in params.keys.toList()..sort()) k: params[k]},
  };

  factory TillCell.fromJson(Object? json) {
    final r = JsonReader.orEmpty(json, context: 'till_layout cell');
    return TillCell(
      kindWire: r.stringOr('kind'),
      col: r.intOrNull('col') ?? 0,
      row: r.intOrNull('row') ?? 0,
      colSpan: r.intOrNull('col_span') ?? 1,
      rowSpan: r.intOrNull('row_span') ?? 1,
      params: r.objectOrAbsent('params').json,
    );
  }
}

/// The grid of one page at one size, and the cells on it.
class TillGrid {
  const TillGrid({required this.cols, required this.rows, this.cells = const []});

  final int cols;
  final int rows;
  final List<TillCell> cells;

  TillGrid withCells(List<TillCell> cells) => TillGrid(cols: cols, rows: rows, cells: List.unmodifiable(cells));

  Map<String, Object?> toJson() => {'cols': cols, 'rows': rows, 'cells': [for (final c in cells) c.toJson()]};

  factory TillGrid.fromJson(Object? json) {
    final r = JsonReader.orEmpty(json, context: 'till_layout grid');
    return TillGrid(
      cols: r.intOrNull('cols') ?? 0,
      rows: r.intOrNull('rows') ?? 0,
      cells: [for (final c in r.listOrAbsent('cells')) TillCell.fromJson(c)],
    );
  }
}

/// One page (tab) of a till: its name and its grid per size.
class TillPage {
  const TillPage({required this.name, required this.grids});

  final String name;
  final Map<TillLayoutSize, TillGrid> grids;

  Map<String, Object?> toJson() => {
    'name': name,
    'grids': {for (final s in TillLayoutSize.values) if (grids[s] != null) s.wire: grids[s]!.toJson()},
  };

  factory TillPage.fromJson(Object? json) {
    final r = JsonReader.orEmpty(json, context: 'till_layout page');
    final grids = <TillLayoutSize, TillGrid>{};
    for (final e in r.objectOrAbsent('grids').json.entries) {
      final size = TillLayoutSize.of(e.key);
      if (size != null) grids[size] = TillGrid.fromJson(e.value);
    }
    return TillPage(name: r.stringOr('name'), grids: grids);
  }
}

/// A till's layout: its name, its version (the server's, for the optimistic save), its status and its pages.
class TillLayout {
  const TillLayout({required this.name, required this.pages, this.version = 0, this.status = TillLayoutStatus.draft});

  final String name;
  final int version;
  final TillLayoutStatus status;
  final List<TillPage> pages;

  /// The layout as the server stores it (the `layout` column): name and status live in their own columns.
  Map<String, Object?> toJson() => {'pages': [for (final p in pages) p.toJson()]};

  factory TillLayout.fromJson(Object? layout, {required String name, int version = 0, TillLayoutStatus status = TillLayoutStatus.draft}) {
    final pages = JsonReader.orEmpty(layout, context: 'till_layout').listOrAbsent('pages');
    return TillLayout(name: name, version: version, status: status, pages: [for (final p in pages) TillPage.fromJson(p)]);
  }

  int get cellCount => pages.fold(0, (a, p) => a + p.grids.values.fold(0, (b, g) => b + g.cells.length));
}

/// Why a layout cannot be saved, with where: the page (from 0), the size and the cell (from 0) when it is about one.
enum TillLayoutProblemCode { noName, noPages, noGrid, badGrid, unknownKind, outsideGrid, tooSmall, overlap, tooLarge, unknownItem, unknownFunction }

class TillLayoutProblem {
  const TillLayoutProblem(this.code, {this.page, this.size, this.cell});

  final TillLayoutProblemCode code;
  final int? page;
  final TillLayoutSize? size;
  final int? cell;

  @override
  String toString() => [code.name, if (page != null) 'page $page', if (size != null) size!.wire, if (cell != null) 'cell $cell'].join(' ');
}

/// The largest layout the server stores, in bytes of its JSON (`till_layout_max_bytes()`).
@visibleForTesting
const int tillLayoutMaxBytes = 262144;

/// The largest grid side a page may have at any size.
@visibleForTesting
const int tillLayoutMaxGridSide = 24;

/// Every problem of [layout]: the rules the server applies when it is saved. [maxCells] is the size cap (the
/// `counter.till_layout_max_cells` setting); [knownItems], when given, are the item ids the business sells.
List<TillLayoutProblem> validateTillLayout(TillLayout layout, {required int maxCells, Set<String>? knownItems}) {
  final out = <TillLayoutProblem>[
    if (layout.name.trim().isEmpty) const TillLayoutProblem(TillLayoutProblemCode.noName),
    if (layout.pages.isEmpty) const TillLayoutProblem(TillLayoutProblemCode.noPages),
  ];
  // past either cap nothing else is looked at, as on the server: a huge layout never costs the overlap check
  if (layout.cellCount > maxCells || utf8.encode(jsonEncode(layout.toJson())).length > tillLayoutMaxBytes) {
    return [...out, const TillLayoutProblem(TillLayoutProblemCode.tooLarge)];
  }
  for (var p = 0; p < layout.pages.length; p++) {
    final page = layout.pages[p];
    if (page.grids.isEmpty) out.add(TillLayoutProblem(TillLayoutProblemCode.noGrid, page: p));
    for (final e in page.grids.entries) {
      out.addAll(_gridProblems(e.value, page: p, size: e.key, knownItems: knownItems));
    }
  }
  return out;
}

bool _gridFits(TillGrid g) => g.cols >= 1 && g.rows >= 1 && g.cols <= tillLayoutMaxGridSide && g.rows <= tillLayoutMaxGridSide;

/// The problems of one grid: its own size, then each cell in order.
List<TillLayoutProblem> _gridProblems(TillGrid g, {required int page, required TillLayoutSize size, Set<String>? knownItems}) {
  if (!_gridFits(g)) return [TillLayoutProblem(TillLayoutProblemCode.badGrid, page: page, size: size)];
  return [
    for (var i = 0; i < g.cells.length; i++)
      for (final code in _cellProblems(g, i, knownItems)) TillLayoutProblem(code, page: page, size: size, cell: i),
  ];
}

bool _inside(TillCell c, TillGrid g) =>
    c.col >= 0 && c.row >= 0 && c.colSpan >= 1 && c.rowSpan >= 1 && c.col + c.colSpan <= g.cols && c.row + c.rowSpan <= g.rows;

/// What is wrong with cell [i] of [g]: its kind, its place, its span, a cell before it on the same place, its function,
/// its item.
List<TillLayoutProblemCode> _cellProblems(TillGrid g, int i, Set<String>? knownItems) {
  final c = g.cells[i];
  final item = c.itemId;
  return [
    if (c.kind == TillWidgetKind.unknown) TillLayoutProblemCode.unknownKind,
    if (!_inside(c, g))
      TillLayoutProblemCode.outsideGrid
    else if (c.colSpan < c.kind.minCols || c.rowSpan < c.kind.minRows)
      TillLayoutProblemCode.tooSmall,
    for (var j = 0; j < i; j++)
      if (c.overlaps(g.cells[j])) TillLayoutProblemCode.overlap,
    if (c.function == TillFunction.unknown) TillLayoutProblemCode.unknownFunction,
    if (knownItems != null && c.kind == TillWidgetKind.itemKey && (item == null || !knownItems.contains(item))) TillLayoutProblemCode.unknownItem,
  ];
}
