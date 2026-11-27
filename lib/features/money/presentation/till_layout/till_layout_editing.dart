// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- what the layout editor holds while it edits: the layout, the version the server last answered, the page and
// size shown, the cell selected, whether there are changes not saved and whether a command runs. The screen listens to
// it; every change goes through one of its methods.
import 'package:flutter/foundation.dart';

import '../../domain/till_layout.dart';
import '../../domain/till_layout_edits.dart';

class TillLayoutEditing extends ChangeNotifier {
  TillLayout? layout;
  int version = 0;
  bool loaded = false;
  bool dirty = false;
  bool busy = false;
  int page = 0;
  int? selected;
  TillLayoutSize size = TillLayoutSize.phone;

  /// The draft read (or, with none, the published layout as a new draft's start); null asks for a template.
  void loadedWith({TillLayout? draft, TillLayout? published}) {
    layout = draft ?? (published == null ? null : TillLayout(name: published.name, pages: published.pages));
    version = draft?.version ?? 0;
    dirty = draft == null && published != null;
    loaded = true;
    notifyListeners();
  }

  void start(TillLayout fromTemplate) {
    layout = fromTemplate;
    dirty = true;
    notifyListeners();
  }

  TillGrid? get grid => layout?.pages[page].grids[size];

  void replaceGrid(TillGrid g, {int? select}) {
    final l = layout!;
    final p = l.pages[page];
    final pages = [...l.pages]..[page] = TillPage(name: p.name, grids: {...p.grids, size: g});
    layout = TillLayout(name: l.name, pages: pages, version: l.version);
    selected = select;
    dirty = true;
    notifyListeners();
  }

  void step(TillCellStep s) {
    final next = stepCell(grid!, selected!, s);
    if (next != null) replaceGrid(next, select: selected);
  }

  void remove() => replaceGrid(removeCell(grid!, selected!));

  void showPage(int p) {
    page = p;
    selected = null;
    notifyListeners();
  }

  void showSize(TillLayoutSize s) {
    size = s;
    selected = null;
    notifyListeners();
  }

  void select(int i) {
    selected = i;
    notifyListeners();
  }

  void running({required bool on}) {
    busy = on;
    notifyListeners();
  }

  /// A save answered [savedVersion]; a publish keeps the draft's version.
  void done({int? savedVersion}) {
    if (savedVersion != null) version = savedVersion;
    dirty = false;
    notifyListeners();
  }
}
