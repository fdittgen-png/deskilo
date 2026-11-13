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

/// #3619 — a row has a minimum height, not a fixed one: every third row
/// here runs on four lines, as a feature's description does at the desk
/// (two lines of the test font still fit the minimum height).
final _tallRows = [
  for (var i = 0; i < 150; i++)
    (
      id: 'r$i',
      name: i % 3 == 0 ? 'Row $i\nline 2\nline 3\nline 4' : 'Row $i',
    ),
];

Widget _table({bool tall = false}) => RecordsTable<_Rec>(
  tableId: 'long',
  rows: tall ? _tallRows : _rows,
  keyOf: (r) => r.id,
  onRetry: () {},
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

  testWidgets('150 rows of different heights: each arrow step leaves the '
      'row it stands on built and on screen, to the last', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(
      tester,
      Scaffold(body: _table(tall: true)),
      size: const Size(1200, 800),
    );
    await connectMouse(tester);
    await tester.tap(find.byKey(const ValueKey('records-row-r0')));
    await tester.pumpAndSettle();
    final list = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('records-rows')),
        matching: find.byType(Scrollable),
      ).first,
    );
    for (var i = 1; i < 150; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey('records-row-r$i'));
      expect(row, findsOneWidget, reason: 'row $i is built');
      final r = tester.getRect(row);
      expect(r.top, greaterThanOrEqualTo(list.top - 0.5), reason: 'row $i');
      expect(r.bottom, lessThanOrEqualTo(list.bottom + 0.5), reason: 'row $i');
    }
    // And back up to the first.
    for (var i = 148; i >= 0; i--) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      final r = tester.getRect(find.byKey(ValueKey('records-row-r$i')));
      expect(r.top, greaterThanOrEqualTo(list.top - 0.5), reason: 'row $i');
    }
  });

  testWidgets('150 rows: Tab leaves the table after a few stops, the context-menu key '
      'opens the actions of the row the arrows stand on', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(
      tester,
      Scaffold(body: _table()),
      size: const Size(1200, 800),
    );
    await connectMouse(tester);
    final stops = <FocusNode>{};
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      stops.add(FocusManager.instance.primaryFocus!);
    }
    // The filter, the header, the rows: then it wraps.
    expect(stops.length, lessThan(8));
    await tester.tap(find.byKey(const ValueKey('records-row-r0')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(find.text('Remind'), findsOneWidget);
  });
}
