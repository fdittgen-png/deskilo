// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4035 — a column's heading and a date are never broken inside the word: a
// column is at least as wide as its longest unbreakable word, and when the
// columns do not fit the width the table drops its least needed column, the
// way it already does on a phone (`shownFrom`). The decisions are pure; a
// table at a narrow width then shows each heading whole.
import 'package:deskilo/core/ui/adaptive/window_class.dart';
import 'package:deskilo/core/ui/kit/records_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/pump_app.dart';

RecordColumn<String> _c(
  String id, {
  int flex = 1,
  bool hideable = true,
  WindowClass shownFrom = WindowClass.compact,
}) => RecordColumn(
  id: id,
  label: id,
  flex: flex,
  hideable: hideable,
  shownFrom: shownFrom,
  cell: (_, r) => Text(r),
);

List<String> _ids(List<RecordColumn<String>> columns) => [
  for (final c in columns) c.id,
];

void main() {
  group('the columns that fit', () {
    final columns = [
      _c('name', hideable: false),
      _c('note', shownFrom: WindowClass.large),
      _c('amount'),
      _c('date', shownFrom: WindowClass.expanded),
    ];
    const mins = {'name': 100.0, 'note': 100.0, 'amount': 100.0, 'date': 100.0};

    test('all of them when their words fit', () {
      expect(_ids(columnsFitting(columns, mins, 400)), [
        'name',
        'note',
        'amount',
        'date',
      ]);
    });

    test('the least needed goes first: the one a wider window shows later, '
        'then the right-most', () {
      expect(_ids(columnsFitting(columns, mins, 350)), [
        'name',
        'amount',
        'date',
      ]);
      expect(_ids(columnsFitting(columns, mins, 250)), ['name', 'amount']);
    });

    test('a column that may not be hidden is never dropped', () {
      expect(_ids(columnsFitting(columns, mins, 10)), ['name']);
    });
  });

  group('the widths', () {
    final columns = [_c('a', flex: 3), _c('b'), _c('c')];

    test('none to decide while every flex share holds its words', () {
      expect(
        recordColumnWidths(columns, const {'a': 50.0, 'b': 50.0, 'c': 50.0}, 500),
        isNull,
      );
    });

    test('a share that cannot hold a word is raised to it, the rest shared '
        'by flex, the sum kept', () {
      final widths = recordColumnWidths(
        columns,
        const {'a': 50.0, 'b': 120.0, 'c': 50.0},
        300,
      )!;
      expect(widths[1], greaterThanOrEqualTo(120));
      expect(widths[0], greaterThanOrEqualTo(50));
      expect(widths.fold<double>(0, (a, b) => a + b), closeTo(300, 0.01));
    });
  });

  testWidgets('at a narrow width a heading is whole and the least needed '
      'column gives way', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(640, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final columns = [
      RecordColumn<String>(
        id: 'name',
        label: 'Name',
        hideable: false,
        flex: 3,
        cell: (_, r) => Text(r),
      ),
      RecordColumn<String>(
        id: 'category',
        label: 'Category',
        sortKey: (r) => r,
        cell: (_, r) => Text(r),
      ),
      RecordColumn<String>(
        id: 'format',
        label: 'Format',
        shownFrom: WindowClass.large,
        sortKey: (r) => r,
        cell: (_, r) => Text(r),
      ),
      RecordColumn<String>(
        id: 'amount',
        label: 'Amount',
        numeric: true,
        sortKey: (r) => r,
        cell: (_, r) => Text(r),
      ),
    ];
    await pumpApp(
      tester,
      Scaffold(
        body: RecordsTable<String>(
          tableId: 'fit-test',
          rows: const ['one', 'two'],
          keyOf: (r) => r,
          columns: columns,
          searchText: (r) => r,
          onOpen: (_) {},
          cardBuilder: (_, r) => Text(r),
          empty: const Text('none'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final id in ['category', 'amount']) {
      final heading = find.descendant(
        of: find.byKey(ValueKey('records-sort-$id')),
        matching: find.byType(Text),
      );
      final box = tester.renderObject<RenderParagraph>(heading.first);
      final lines = box.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: box.text.toPlainText().length),
      );
      expect({for (final b in lines) b.top.round()}, hasLength(1), reason: id);
    }
    expect(find.byKey(const ValueKey('records-sort-format')), findsNothing);
  });
}
