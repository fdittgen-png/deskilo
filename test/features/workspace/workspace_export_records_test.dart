// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2860 — the tables `export_workspace_records` (0540) answers become one
// sheet each: the column names first, then the rows, a nested value as its
// JSON text.
import 'package:deskilo/core/files/xlsx.dart';
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
      final sheets = exportedTableSheets(tables, currencyCode: 'EUR');
      expect([for (final s in sheets) s.name], ['plans', 'suppliers']);
      final rows = sheets.first.rows;
      expect(rows.first, ['id', 'name', 'price_cents', 'rules']);
      expect(rows[1][0], 'p1');
      expect((rows[1][2]! as XlsxAmount).value, 250.0,
          reason: 'a *_cents column is an amount in major units (#2861)');
      expect(rows[1][3], '{"days":5}');
      expect(rows[2][3], isNull);
      expect(sheets.last.rows, [
        ['id', 'name'],
      ], reason: 'an empty table still names its columns');
    },
  );

  test('an answer that is not a list reads as no table', () {
    expect(exportedTablesFromJson(null), isEmpty);
    expect(exportedTablesFromJson({'x': 1}), isEmpty);
  });

  test('a timestamp is a date at the workspace clock, a day a date (#2861)',
      () {
    final sheet = exportedTableSheets(
      exportedTablesFromJson([
        {
          'table': 'closure_days',
          'columns': ['day', 'created_at'],
          'rows': [
            ['2026-08-15', '2026-08-01T07:00:00+00:00'],
          ],
        },
      ]),
      currencyCode: 'EUR',
    ).single;
    expect(sheet.rows[1][0], isA<XlsxDate>());
    expect(sheet.rows[1][1], isA<DateTime>());
  });
}
