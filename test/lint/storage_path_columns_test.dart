// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3985 -- the server removes stored files no column names
// (invoice_originals_sweep_claim_v1). Removing a file cannot be undone, so the
// list of columns that store a storage path, public.storage_path_columns(),
// must name every one: a new column holding a path that is missing from it
// would let the sweep take a file that column still names.
//
// This reads every migration for a text column called `path` or ending in
// `_path` -- in a table's definition or an added column -- and requires the
// set to be exactly the list in the latest definition of
// storage_path_columns(). A new such column fails here until it is listed
// (or renamed, if it is not a storage path).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _createTable = RegExp(
  r'create table (?:if not exists )?public\.(\w+)\s*\(',
  caseSensitive: false,
);
final _addColumn = RegExp(
  r'alter table (?:only )?(?:if exists )?public\.(\w+)\s+add column (?:if not exists )?(\w+)\s+text\b',
  caseSensitive: false,
);
final _dropColumn = RegExp(
  r'alter table (?:only )?(?:if exists )?public\.(\w+)\s+drop column (?:if exists )?(\w+)',
  caseSensitive: false,
);
final _column = RegExp(
  r'^\s*(\w+)\s+text\b',
  caseSensitive: false,
  multiLine: true,
);
final _listed = RegExp(r"\('(\w+)',\s*'(\w+)',\s*'[\w-]+'\)");

bool _isPath(String column) => column == 'path' || column.endsWith('_path');

/// The body of the table definition that starts at [open] (its "("), up to
/// the matching ")".
String _body(String sql, int open) {
  var depth = 0;
  for (var i = open; i < sql.length; i++) {
    if (sql[i] == '(') depth++;
    if (sql[i] == ')' && --depth == 0) return sql.substring(open + 1, i);
  }
  return sql.substring(open + 1);
}

/// Every `table.column` of a storage path the migrations leave in the schema.
Set<String> pathColumns(Iterable<String> migrations) {
  final found = <String>{};
  for (final raw in migrations) {
    final sql = raw
        .split('\n')
        .map((l) => l.contains('--') ? l.substring(0, l.indexOf('--')) : l)
        .join('\n');
    for (final m in _createTable.allMatches(sql)) {
      for (final c in _column.allMatches(_body(sql, m.end - 1))) {
        if (_isPath(c.group(1)!.toLowerCase())) {
          found.add('${m.group(1)}.${c.group(1)!.toLowerCase()}');
        }
      }
    }
    for (final m in _addColumn.allMatches(sql)) {
      if (_isPath(m.group(2)!.toLowerCase())) {
        found.add('${m.group(1)}.${m.group(2)!.toLowerCase()}');
      }
    }
    for (final m in _dropColumn.allMatches(sql)) {
      found.remove('${m.group(1)}.${m.group(2)!.toLowerCase()}');
    }
  }
  return found;
}

/// The columns the latest storage_path_columns() lists.
Set<String> listedColumns(Iterable<String> migrations) {
  final defining = migrations
      .where((s) => s.contains('function public.storage_path_columns()'))
      .toList();
  if (defining.isEmpty) return const {};
  final body = defining.last.substring(
    defining.last.indexOf('function public.storage_path_columns()'),
  );
  final end = body.indexOf(r'$fn$;');
  return {
    for (final m in _listed.allMatches(end < 0 ? body : body.substring(0, end)))
      '${m.group(1)}.${m.group(2)}',
  };
}

void main() {
  test('a table definition, an added and a dropped column are read', () {
    const sql = '''
create table public.a (
  id uuid primary key,
  file_path text not null, -- a stored file
  name text
);
alter table public.b add column if not exists cover_path text;
alter table public.b add column title text;
alter table public.c add column old_path text;
alter table public.c drop column old_path;
''';
    expect(pathColumns([sql]), {'a.file_path', 'b.cover_path'});
  });

  test(
    'every column that stores a storage path is in storage_path_columns()',
    () {
      final migrations = [
        for (final f in sqlFiles('supabase/migrations'))
          File(f.path).readAsStringSync(),
      ];
      final listed = listedColumns(migrations);
      expect(
        listed,
        isNotEmpty,
        reason: 'storage_path_columns() is defined by a migration',
      );
      final found = pathColumns(migrations);
      expect(
        found.difference(listed),
        isEmpty,
        reason:
            'a column holding a storage path is missing from storage_path_columns(): '
            'the sweep could remove a file it still names -- restate the function with it',
      );
      expect(
        listed.difference(found),
        isEmpty,
        reason: 'storage_path_columns() names a column no migration leaves in the schema',
      );
    },
  );
}
