// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3606 (desk K1) — what a records table decides, apart from how it draws:
// the columns, the row actions, the query (text, chip, sort), the selection
// and the totals. Pure, so the rules are tested without a widget.
//
// Rows have stable keys (a page whose rows come from several sources or
// workspaces qualifies them); the selection is a set of those keys,
// reconciled when the rows or the query change, never row positions. A
// total carries its scope (what it adds up) and whether everything it could
// add is loaded; it is per currency and never one sum across currencies.
import 'package:flutter/widgets.dart';

/// One column of a records table.
@immutable
class RecordColumn<T> {
  const RecordColumn({
    required this.id,
    required this.label,
    required this.cell,
    this.flex = 1,
    this.numeric = false,
    this.sortKey,
    this.hideable = true,
  });

  /// Stable, for the column choice kept on the device.
  final String id;
  final String label;
  final Widget Function(BuildContext context, T row) cell;
  final int flex;

  /// Right-aligned, tabular figures.
  final bool numeric;

  /// Sortable when given: the value the column sorts by.
  final Comparable<Object?> Function(T row)? sortKey;

  /// Whether the person may hide it (the first column may not).
  final bool hideable;
}

/// One action on a row, declared once: the ⋯ button, the secondary click
/// and the long press all offer it (the shape the row menu takes, #3611).
@immutable
class RecordAction<T> {
  const RecordAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onRun,
    this.destructive = false,
    this.unavailable,
  });

  final String id;
  final String label;
  final IconData icon;
  final void Function(T row) onRun;
  final bool destructive;

  /// Why it cannot run now; null when it can.
  final String? unavailable;
}

/// An action on the selected rows: it receives exactly their keys.
@immutable
class RecordBulkAction {
  const RecordBulkAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onRun,
  });

  final String id;

  /// The action's words for [count] rows ("Export 3 invoices").
  final String Function(int count) label;
  final IconData icon;
  final void Function(Set<String> keys) onRun;
}

/// A filter chip: its words and which rows it keeps.
@immutable
class RecordChip<T> {
  const RecordChip({
    required this.id,
    required this.label,
    required this.keeps,
  });

  final String id;
  final String label;
  final bool Function(T row) keeps;
}

/// An amount a row adds to the totals.
typedef RecordAmount = ({String currency, int minor});

/// What the table shows: the typed text, the chip, the sort.
@immutable
class RecordsQuery {
  const RecordsQuery({
    this.text = '',
    this.chip,
    this.sortColumn,
    this.ascending = true,
  });

  final String text;
  final String? chip;
  final String? sortColumn;
  final bool ascending;

  RecordsQuery copyWith({
    String? text,
    String? Function()? chip,
    String? Function()? sortColumn,
    bool? ascending,
  }) => RecordsQuery(
    text: text ?? this.text,
    chip: chip == null ? this.chip : chip(),
    sortColumn: sortColumn == null ? this.sortColumn : sortColumn(),
    ascending: ascending ?? this.ascending,
  );
}

/// The rows [query] keeps of [rows], in its order. [searchText] is what a
/// typed text is looked for in.
@visibleForTesting
List<T> queryRows<T>(
  List<T> rows,
  RecordsQuery query, {
  required String Function(T row) searchText,
  required List<RecordChip<T>> chips,
  required List<RecordColumn<T>> columns,
}) {
  final needle = query.text.trim().toLowerCase();
  final chip = chips.where((c) => c.id == query.chip).firstOrNull;
  final kept = [
    for (final r in rows)
      if ((needle.isEmpty || searchText(r).toLowerCase().contains(needle)) &&
          (chip == null || chip.keeps(r)))
        r,
  ];
  final sortBy = columns
      .where((c) => c.id == query.sortColumn && c.sortKey != null)
      .firstOrNull
      ?.sortKey;
  if (sortBy != null) {
    // Stable: equal keys keep the order the rows came in.
    final indexed = [for (final (i, r) in kept.indexed) (i, r)]
      ..sort((a, b) {
        final c = sortBy(a.$2).compareTo(sortBy(b.$2));
        final order = query.ascending ? c : -c;
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return [for (final (_, r) in indexed) r];
  }
  return kept;
}

/// How many of [rows] each chip keeps (with the typed text applied).
Map<String, int> chipCounts<T>(
  List<T> rows,
  String text, {
  required String Function(T row) searchText,
  required List<RecordChip<T>> chips,
}) {
  final needle = text.trim().toLowerCase();
  final matching = [
    for (final r in rows)
      if (needle.isEmpty || searchText(r).toLowerCase().contains(needle)) r,
  ];
  return {for (final c in chips) c.id: matching.where(c.keeps).length};
}

/// [selected] kept to the keys still among [present]: a row that left the
/// data (or the workspace) leaves the selection. [dropped] counts those.
({Set<String> kept, int dropped}) _reconcileSelection(
  Set<String> selected,
  Iterable<String> present,
) {
  final here = present.toSet();
  final kept = selected.intersection(here);
  return (kept: kept, dropped: selected.length - kept.length);
}

/// What a total adds up: the rows shown, or the selection.
enum TotalScope { shown, selection }

/// The totals of [rows], one per currency, never one across them.
Map<String, int> totalsByCurrency<T>(
  Iterable<T> rows,
  RecordAmount? Function(T row) amountOf,
) {
  final out = <String, int>{};
  for (final r in rows) {
    final a = amountOf(r);
    if (a == null) continue;
    out[a.currency] = (out[a.currency] ?? 0) + a.minor;
  }
  return out;
}

/// #3606 — a records table's state: the query, the selection (and how many
/// selected rows a reload dropped), the focused row and the hidden columns.
/// Every change reconciles the selection with what is SHOWN in one place,
/// so an action never reaches a row the table does not show.
class RecordsController<T> extends ChangeNotifier {
  RecordsController({
    required this._query,
    required this.keyOf,
    required this.searchText,
    required this._chips,
    required this._columns,
  });

  final String Function(T row) keyOf;
  final String Function(T row) searchText;
  List<RecordChip<T>> _chips;
  List<RecordColumn<T>> _columns;
  List<T> _rows = const [];
  RecordsQuery _query;
  Set<String> _selected = {};
  int _dropped = 0;
  int _focused = 0;
  Set<String> _hidden = {};
  List<T>? _shown;

  RecordsQuery get query => _query;
  Set<String> get selected => Set.unmodifiable(_selected);
  int get dropped => _dropped;
  int get focused => _focused;
  Set<String> get hidden => Set.unmodifiable(_hidden);

  /// The rows the query keeps, in its order.
  List<T> get shown => _shown ??= queryRows(
    _rows,
    _query,
    searchText: searchText,
    chips: _chips,
    columns: _columns,
  );

  /// The selection kept to what is shown. [said]: a row that left was
  /// taken away (a reload), not filtered out by the person.
  void _reconcile({required bool said}) {
    _shown = null;
    final r = _reconcileSelection(_selected, shown.map(keyOf));
    _selected = r.kept;
    if (said && r.dropped > 0) _dropped = r.dropped;
    _focused = shown.isEmpty ? 0 : _focused.clamp(0, shown.length - 1);
  }

  /// New rows, or new chips or columns: the selection follows what is shown.
  void rowsChanged(
    List<T> rows, {
    required List<RecordChip<T>> chips,
    required List<RecordColumn<T>> columns,
  }) {
    _rows = rows;
    _chips = chips;
    _columns = columns;
    _reconcile(said: true);
    notifyListeners();
  }

  void setQuery(RecordsQuery query) {
    _query = query;
    _focused = 0;
    _reconcile(said: false);
    notifyListeners();
  }

  /// A click on column [id]: sorts by it, a second reverses.
  void sortBy(String id) => setQuery(
    _query.sortColumn == id
        ? _query.copyWith(ascending: !_query.ascending)
        : _query.copyWith(sortColumn: () => id, ascending: true),
  );

  void tick(String key, {required bool on}) {
    if (on && !shown.map(keyOf).contains(key)) return;
    _selected = on ? {..._selected, key} : ({..._selected}..remove(key));
    _dropped = 0;
    notifyListeners();
  }

  /// Every shown row, or none of them.
  void selectShown({required bool on}) {
    final keys = shown.map(keyOf).toSet();
    _selected = on ? {..._selected, ...keys} : _selected.difference(keys);
    _dropped = 0;
    notifyListeners();
  }

  void clear() {
    _selected = {};
    _dropped = 0;
    notifyListeners();
  }

  void move(int by) {
    if (shown.isEmpty) return;
    _focused = (_focused + by).clamp(0, shown.length - 1);
    notifyListeners();
  }

  void focus(int index) {
    _focused = index;
    notifyListeners();
  }

  void toggleColumn(String id) {
    _hidden = _hidden.contains(id)
        ? ({..._hidden}..remove(id))
        : {..._hidden, id};
    notifyListeners();
  }

  /// The hidden columns read back from the device.
  void restoreHidden(Set<String> hidden) {
    _hidden = hidden;
    notifyListeners();
  }
}
