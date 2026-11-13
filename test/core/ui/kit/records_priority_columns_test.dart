// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3860 — a records table with a record open beside it keeps the columns
// that declare they stay; closing the pane brings the rest back; the
// person's hidden columns hold throughout. The decision "a record is open
// beside" comes from the scaffold, never from a width in the table.
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/storage/pane_width_store.dart';
import 'package:deskilo/core/ui/kit/list_detail_scaffold.dart';
import 'package:deskilo/core/ui/kit/records_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/pump_app.dart';

List<RecordColumn<String>> _columns() => [
  RecordColumn(
    id: 'name',
    label: 'Name',
    hideable: false,
    cell: (_, r) => Text(r),
  ),
  RecordColumn(
    id: 'note',
    label: 'Note',
    staysBeside: false,
    cell: (_, r) => Text(r),
  ),
  RecordColumn(
    id: 'amount',
    label: 'Amount',
    numeric: true,
    cell: (_, r) => Text(r),
  ),
  RecordColumn(
    id: 'date',
    label: 'Date',
    staysBeside: false,
    cell: (_, r) => Text(r),
  ),
];

Set<String> _ids(List<RecordColumn<String>> columns) => {
  for (final c in columns) c.id,
};

class _Host extends StatelessWidget {
  const _Host({required this.selected, required this.store});

  final ValueNotifier<String?> selected;
  final PaneWidthStore store;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: selected,
    builder: (context, id, _) => ListDetailScaffold(
      id: 'priority-test',
      paneStore: store,
      selected: id,
      onClose: () => selected.value = null,
      detail: (_, id) => Text('record $id'),
      list: RecordsTable<String>(
        tableId: 'priority-test',
        rows: const ['one', 'two'],
        keyOf: (r) => r,
        searchText: (r) => r,
        onOpen: (r) => selected.value = r,
        columns: _columns(),
        cardBuilder: (_, r) => Text(r),
        empty: const Text('none'),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<String?> selected, {
  Size size = const Size(1440, 900),
}) async {
  SharedPreferences.setMockInitialValues({});
  await pumpApp(
    tester,
    Scaffold(
      body: _Host(selected: selected, store: InMemoryPaneWidthStore()),
    ),
    size: size,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('columnsShown', () {
    final all = _columns();

    test('alone: every column the person has not hidden', () {
      expect(_ids(columnsShown(all, {'note'}, beside: false)), {
        'name',
        'amount',
        'date',
      });
    });

    test('beside a record: only the staying columns', () {
      expect(_ids(columnsShown(all, const {}, beside: true)), {
        'name',
        'amount',
      });
    });

    test('beside a record the hidden choice still holds', () {
      expect(_ids(columnsShown(all, {'amount'}, beside: true)), {'name'});
    });

    test('a column that may not be hidden stays, declared or not', () {
      final cols = [
        RecordColumn<String>(
          id: 'name',
          label: 'Name',
          hideable: false,
          staysBeside: false,
          cell: (_, r) => Text(r),
        ),
        RecordColumn<String>(
          id: 'note',
          label: 'Note',
          staysBeside: false,
          cell: (_, r) => Text(r),
        ),
      ];
      expect(_ids(columnsShown(cols, const {}, beside: true)), {'name'});
    });

    test('where none would stay the table is not emptied', () {
      final cols = [
        RecordColumn<String>(
          id: 'a',
          label: 'A',
          staysBeside: false,
          cell: (_, r) => Text(r),
        ),
        RecordColumn<String>(
          id: 'b',
          label: 'B',
          staysBeside: false,
          cell: (_, r) => Text(r),
        ),
      ];
      expect(_ids(columnsShown(cols, const {}, beside: true)), {'a', 'b'});
    });
  });

  testWidgets('opening a record drops the columns that do not stay and '
      'closing brings them back', (tester) async {
    final selected = ValueNotifier<String?>(null);
    addTearDown(selected.dispose);
    await _pump(tester, selected);
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('DATE'), findsOneWidget);

    selected.value = 'one';
    await tester.pumpAndSettle();
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);
    expect(find.text('NOTE'), findsNothing);
    expect(find.text('DATE'), findsNothing);

    selected.value = null;
    await tester.pumpAndSettle();
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('DATE'), findsOneWidget);
  });

  testWidgets('a column the person hid stays hidden through opening and '
      'closing', (tester) async {
    final selected = ValueNotifier<String?>(null);
    addTearDown(selected.dispose);
    await _pump(tester, selected);
    await tester.tap(find.byKey(const ValueKey('records-columns')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('records-column-note')).first);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('NOTE'), findsNothing);

    selected.value = 'one';
    await tester.pumpAndSettle();
    expect(find.text('NOTE'), findsNothing);
    selected.value = null;
    await tester.pumpAndSettle();
    expect(find.text('NOTE'), findsNothing);
    expect(find.text('DATE'), findsOneWidget);
  });

  testWidgets('a pane standing over the list, not beside it, keeps every '
      'column', (tester) async {
    final selected = ValueNotifier<String?>('one');
    addTearDown(selected.dispose);
    // Too narrow for the list and the narrowest pane side by side.
    await _pump(tester, selected, size: const Size(700, 800));
    expect(find.byKey(const ValueKey('list-detail-grip')), findsNothing);
    expect(find.text('NOTE'), findsOneWidget);
  });
}
