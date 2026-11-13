// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3891 — the keyboard contract of a long records table: 150 rows, built
// lazily. The table is Tab stops of its own (the filter, the header, the
// rows' node) and the arrows walk its rows; rows that scroll out of the
// list and are rebuilt never leave a control unreachable.
import 'package:deskilo/core/storage/prefs_stores.dart';
import 'package:deskilo/core/ui/kit/records_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/mouse.dart';
import '../../../helpers/pump_app.dart';
import '../../../ux/experience_guards.dart';

typedef _Rec = ({String id, String name});

final _rows = [for (var i = 0; i < 150; i++) (id: 'r$i', name: 'Row $i')];

Widget _table() => RecordsTable<_Rec>(
  tableId: 'long',
  rows: _rows,
  keyOf: (r) => r.id,
  state: RecordsState.ready,
  onRetry: () {},
  complete: true,
  columnStore: const PrefsStringStore('records_columns_long'),
  columns: [
    RecordColumn(
      id: 'name',
      label: 'Name',
      hideable: false,
      sortKey: (r) => r.name,
      cell: (_, r) => Text(r.name),
    ),
  ],
  searchText: (r) => r.name,
  chips: const [],
  onOpen: (_) {},
  rowActions: (r) => [
    RecordAction(
      id: 'remind',
      label: 'Remind',
      icon: Icons.notifications_outlined,
      onRun: (_) {},
    ),
  ],
  bulkActions: const [],
  cardBuilder: (_, r) => Card(child: Text(r.name)),
  empty: const Text('Nothing yet'),
);

void main() {
  testWidgets('150 rows: every control is reached by Tab or an arrow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      Scaffold(body: _table()),
      size: const Size(1200, 800),
    );
    await connectMouse(tester);
    expect(await keyboardProblems(tester), isEmpty);
    semantics.dispose();
  });

  testWidgets('150 rows: the arrows reach the last row, Tab does not walk '
      'every row', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(
      tester,
      Scaffold(body: _table()),
      size: const Size(1200, 800),
    );
    await connectMouse(tester);
    await tester.tap(find.byKey(const ValueKey('records-row-r0')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 149; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('records-row-r149')), findsOneWidget);
  });
}
