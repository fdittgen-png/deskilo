// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2860 — the tables `export_workspace_records` (0540) answers become one
// sheet each: the column names first, then the rows, a nested value as its
// JSON text.
import 'package:deskilo/features/workspace/domain/workspace_export_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'each table is a sheet of its columns and rows, in the server order',
    () {
      final tables = exportedTablesFromJson([
        {
          'table': 'plans',
          'columns': ['id', 'name', 'price_cents', 'rules'],
          'rows': [
            [
              'p1',
              'Full time',
              25000,
              {'days': 5},
            ],
            ['p2', 'Part time', 15000, null],
          ],
        },
        {
          'table': 'suppliers',
          'columns': ['id', 'name'],
          'rows': <Object?>[],
        },
      ]);
      final sheets = exportedTableSheets(tables);
      expect([for (final s in sheets) s.name], ['plans', 'suppliers']);
      expect(sheets.first.rows, [
        ['id', 'name', 'price_cents', 'rules'],
        ['p1', 'Full time', 25000, '{"days":5}'],
        ['p2', 'Part time', 15000, null],
      ]);
      expect(sheets.last.rows, [
        ['id', 'name'],
      ], reason: 'an empty table still names its columns');
    },
  );

  test('an answer that is not a list reads as no table', () {
    expect(exportedTablesFromJson(null), isEmpty);
    expect(exportedTablesFromJson({'x': 1}), isEmpty);
  });
}
