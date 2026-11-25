// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4404 -- what a Demo fake does by hand with its rows: find one by id, put one back in its place or add it, count the next id. The
// rows stay a plain list (a test reads and fills `fake.suppliers` as it always did); the table adds the few things every fake wrote
// again. A new fake declares its rows and how a row is told from another, and writes only its own rules.
import 'dart:collection';

class DemoTable<T> extends ListBase<T> {
  /// [idOf] tells a row from another (null for a row that has none yet); [rows] are the ones it starts with.
  DemoTable(this._idOf, [Iterable<T> rows = const []]) : _rows = [...rows];

  final String? Function(T row) _idOf;
  final List<T> _rows;

  @override
  int get length => _rows.length;

  @override
  set length(int value) => _rows.length = value;

  // growing goes through the rows, never through the length (a list of non-null rows cannot be padded)
  @override
  void add(T element) => _rows.add(element);

  @override
  void addAll(Iterable<T> iterable) => _rows.addAll(iterable);

  @override
  void insert(int index, T element) => _rows.insert(index, element);

  @override
  void insertAll(int index, Iterable<T> iterable) => _rows.insertAll(index, iterable);

  @override
  T removeAt(int index) => _rows.removeAt(index);

  @override
  void clear() => _rows.clear();

  @override
  T operator [](int index) => _rows[index];

  @override
  void operator []=(int index, T value) => _rows[index] = value;

  /// Where the row with [id] is, or -1 (also for a null id: a row that has none yet is nobody's).
  int indexOfId(String? id) => id == null ? -1 : _rows.indexWhere((r) => _idOf(r) == id);

  /// The row with [id], or null.
  T? byId(String? id) {
    final i = indexOfId(id);
    return i < 0 ? null : _rows[i];
  }

  /// Puts [row] in the place of the row that has its id, or adds it; answers where it is.
  int upsert(T row) {
    final i = indexOfId(_idOf(row));
    if (i < 0) {
      _rows.add(row);
      return _rows.length - 1;
    }
    _rows[i] = row;
    return i;
  }

  /// The id a new row takes: `demo-[stem]-N`, N one more than the rows held.
  String nextId(String stem) => 'demo-$stem-${_rows.length + 1}';
}
