// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in configuration_classification_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The six columns `ensure_system_columns()` puts on EVERY table (0184,
/// #992). They are never named in a `workspaces` statement, so a parser
/// that only reads that table's own SQL would miss them — and then pass
/// while six columns went unclassified.
const systemColumns = {
  'created_datetime',
  'modified_datetime',
  'company_id',
  'site_id',
  'created_by_user',
  'modified_by_user',
};

final createTable = RegExp(
  r'create table public\.workspaces\s*\((.*?)\n\);',
  dotAll: true,
);

final createColumn = RegExp(
  r'^([a-z_]+)\s+(uuid|text|jsonb|boolean|smallint|int|timestamptz)',
);

/// `alter table public.workspaces … ;` — the whole statement, because
/// many of them put the table on one line and the column on the next.
/// A single-line pattern finds five of the twenty-eight.
final alterStatement = RegExp(
  r'alter table public\.workspaces\b(.*?);',
  dotAll: true,
);

final addColumn = RegExp(r'add column\s+(?:if not exists\s+)?([a-z_]+)');

/// Every column `workspaces` has, according to the migrations.
Set<String> workspaceColumns() {
  final columns = <String>{...systemColumns};
  for (final file
      in Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path))) {
    final sql = file.readAsStringSync();
    final created = createTable.firstMatch(sql);
    if (created != null) {
      for (final line in created.group(1)!.split('\n')) {
        final column = createColumn.firstMatch(line.trim());
        if (column != null) columns.add(column.group(1)!);
      }
    }
    for (final statement in alterStatement.allMatches(sql)) {
      for (final column in addColumn.allMatches(statement.group(1)!)) {
        columns.add(column.group(1)!);
      }
    }
  }
  return columns;
}

/// The entity keys, from the LATEST migration that defines the function.
/// 0186 introduced it and 0219 restated it; reading the earlier one would
/// classify a set nobody deploys any more.
Set<String> deployableEntityKeys() {
  final defining =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.sql') &&
                f.readAsStringSync().contains(
                  'function public.deployable_entities',
                ),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  expect(
    defining,
    isNotEmpty,
    reason: 'no migration defines deployable_entities()',
  );
  final keys = RegExp(r"'key',\s*'([a-z_]+)'")
      .allMatches(defining.last.readAsStringSync())
      .map((m) => m.group(1)!)
      .toSet();
  // Later migrations add entities by anchored patch rather than by
  // restating the function (0220 number_sequences, 0223 lexicon). An
  // entity object always carries `'kind'` right after its key, which no
  // other `'key'` in a migration does.
  final start = defining.last.path.split('/').last;
  for (final f in Directory(
    'supabase/migrations',
  ).listSync().whereType<File>()) {
    final name = f.path.split('/').last;
    if (!name.endsWith('.sql') || name.compareTo(start) <= 0) continue;
    keys.addAll(
      RegExp(r"'key',\s*'([a-z_]+)',\s*'kind'")
          .allMatches(f.readAsStringSync())
          .map((m) => m.group(1)!),
    );
  }
  return keys;
}
