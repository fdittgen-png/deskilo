// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3606 — the records table's controller on its own: whatever changes (the
// query, the rows, the chips), the selection never holds a row the table
// does not show, and a row taken away by a reload is counted.
import 'package:deskilo/core/ui/kit/records_table_model.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Rec = ({String id, String name, bool late});

final _late = RecordChip<_Rec>(id: 'late', label: 'Late', keeps: (r) => r.late);

RecordsController<_Rec> _controller(List<_Rec> rows) => RecordsController<_Rec>(
  query: const RecordsQuery(),
  keyOf: (r) => r.id,
  searchText: (r) => r.name,
  chips: [_late],
  columns: const [],
)..rowsChanged(rows, chips: [_late], columns: const []);

const _a = (id: 'a', name: 'Ada', late: true);
const _b = (id: 'b', name: 'Bruno', late: false);
const _c = (id: 'c', name: 'Chiara', late: true);

void main() {
  test('the selection stays inside what is shown after every change', () {
    final c = _controller([_a, _b, _c]);
    void inside() => expect(
      c.selected.difference(c.shown.map((r) => r.id).toSet()),
      isEmpty,
    );
    c.selectShown(on: true);
    inside();
    c.setQuery(c.query.copyWith(chip: () => 'late'));
    inside();
    expect(c.selected, {'a', 'c'});
    expect(c.dropped, 0, reason: 'a filter by the person is not a drop');
    c.rowsChanged(
      [(id: 'a', name: 'Ada', late: false), _b, _c],
      chips: [_late],
      columns: const [],
    );
    inside();
    expect(c.selected, {'c'});
    expect(c.dropped, 1);
    c.setQuery(c.query.copyWith(text: 'zzz'));
    inside();
    expect(c.selected, isEmpty);
  });

  test('a row that is not shown cannot be ticked; a tick clears the drop', () {
    final c = _controller([_a, _b, _c])
      ..setQuery(const RecordsQuery(chip: 'late'))
      ..tick('b', on: true);
    expect(c.selected, isEmpty);
    c
      ..tick('a', on: true)
      ..rowsChanged([_c], chips: [_late], columns: const []);
    expect(c.dropped, 1);
    c.tick('c', on: true);
    expect(c.selected, {'c'});
    expect(c.dropped, 0);
  });

  test('the focused row stays on a shown row; columns toggle', () {
    final c = _controller([_a, _b, _c])..move(5);
    expect(c.focused, 2);
    c.rowsChanged([_a], chips: [_late], columns: const []);
    expect(c.focused, 0);
    c.toggleColumn('amount');
    expect(c.hidden, {'amount'});
    c.toggleColumn('amount');
    expect(c.hidden, isEmpty);
  });

  test('a click on the sorted column reverses it', () {
    final c = _controller([_a])..sortBy('name');
    expect((c.query.sortColumn, c.query.ascending), ('name', true));
    c.sortBy('name');
    expect(c.query.ascending, isFalse);
  });
}
