// SPDX-License-Identifier: 0BSD
//
// #1290 S2 — nothing configurable stays unclassified.
//
// `docs/domain/CONFIGURATION_MATRIX.md` says, for every setting, whether
// it travels with a template and why. A document like that is true on
// the day it is written and drifts every day after, so this reads the
// same sources the matrix was built from and fails when one of them has
// grown a row the matrix does not answer for.
//
// Two sources, because the two ways a setting appears are different:
//
//   * every column of `workspaces` — the settings a space stores;
//   * every key of `deployable_entities()` — the things a deployment or
//     a template actually moves.
//
// The columns are read from the migrations rather than from a live
// database, the way `privacy_claims_test` reads its SQL: a lint that
// needs a connection is a lint that gets skipped.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _matrix = 'docs/domain/CONFIGURATION_MATRIX.md';

/// The six columns `ensure_system_columns()` puts on EVERY table (0184,
/// #992). They are never named in a `workspaces` statement, so a parser
/// that only reads that table's own SQL would miss them — and then pass
/// while six columns went unclassified.
const _systemColumns = {
  'created_datetime',
  'modified_datetime',
  'company_id',
  'site_id',
  'created_by_user',
  'modified_by_user',
};

final _createTable =
    RegExp(r'create table public\.workspaces\s*\((.*?)\n\);', dotAll: true);
final _createColumn = RegExp(
    r'^([a-z_]+)\s+(uuid|text|jsonb|boolean|smallint|int|timestamptz)');

/// `alter table public.workspaces … ;` — the whole statement, because
/// many of them put the table on one line and the column on the next.
/// A single-line pattern finds five of the twenty-eight.
final _alterStatement =
    RegExp(r'alter table public\.workspaces\b(.*?);', dotAll: true);
final _addColumn =
    RegExp(r'add column\s+(?:if not exists\s+)?([a-z_]+)');

/// Every column `workspaces` has, according to the migrations.
Set<String> workspaceColumns() {
  final columns = <String>{..._systemColumns};
  for (final file in Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path))) {
    final sql = file.readAsStringSync();
    final created = _createTable.firstMatch(sql);
    if (created != null) {
      for (final line in created.group(1)!.split('\n')) {
        final column = _createColumn.firstMatch(line.trim());
        if (column != null) columns.add(column.group(1)!);
      }
    }
    for (final statement in _alterStatement.allMatches(sql)) {
      for (final column in _addColumn.allMatches(statement.group(1)!)) {
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
  final defining = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.sql') &&
          f.readAsStringSync().contains('function public.deployable_entities'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  expect(defining, isNotEmpty,
      reason: 'no migration defines deployable_entities()');
  return RegExp(r"'key',\s*'([a-z_]+)'")
      .allMatches(defining.last.readAsStringSync())
      .map((m) => m.group(1)!)
      .toSet();
}

/// Every name the matrix classifies.
///
/// A cell may hold several — `country_code, currency_code, timezone` —
/// and may decorate one: `booking_rules (open_weekdays, granularity…)`.
/// Splitting naively would report settings as unclassified when they are
/// sitting right there, and a lint that cries wolf is a lint people learn
/// to skip.
Set<String> classifiedNames() {
  final names = <String>{};
  for (final line in File(_matrix).readAsLinesSync()) {
    if (!line.startsWith('|')) continue;
    final cells = line.split('|').map((c) => c.trim()).toList();
    if (cells.length < 3) continue;
    var first = cells[1]
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll('`', ' ')
        .replaceAll('*', ' ');
    for (final piece in first.split(RegExp(r'[,\s]+'))) {
      final name = piece.trim();
      if (RegExp(r'^[a-z][a-z_]*$').hasMatch(name)) names.add(name);
    }
  }
  return names;
}

void main() {
  test('the matrix exists and classifies something', () {
    expect(File(_matrix).existsSync(), isTrue,
        reason: '$_matrix is the document this lint enforces (#1290)');
    expect(classifiedNames().length, greaterThan(40),
        reason: 'the matrix parsed to almost nothing — the row format '
            'changed and this lint is now measuring the parser');
  });

  test('every workspaces column is classified', () {
    final classified = classifiedNames();
    final missing = workspaceColumns().difference(classified).toList()..sort();

    expect(missing, isEmpty,
        reason: 'these columns of `workspaces` have no row in the '
            'configuration matrix, so nobody has decided whether they '
            'travel with a template:\n  ${missing.join('\n  ')}\n'
            'Add a row to $_matrix with its class (A–F) and, if it '
            'travels, its merge policy.');
  });

  test('every deployable entity is classified', () {
    final classified = classifiedNames();
    final missing = deployableEntityKeys().difference(classified).toList()
      ..sort();

    expect(missing, isEmpty,
        reason: 'these keys of `deployable_entities()` have no row in the '
            'configuration matrix:\n  ${missing.join('\n  ')}\n'
            'A new entity is unclassified until somebody says what it is.');
  });

  test('the parse reproduces the table it claims to read', () {
    // 42 at the time of writing: 8 from the create, 28 from the alters —
    // including the ones that put the column on the following line — and
    // the 6 system columns. If this number moves, the test above is
    // measuring a different table than the matrix classifies.
    expect(workspaceColumns().length, greaterThanOrEqualTo(42),
        reason: 'the workspaces parse found fewer columns than the 42 the '
            'matrix was built against — a statement shape it cannot read '
            'was added, and unclassified columns would now pass silently');
    expect(deployableEntityKeys().length, greaterThanOrEqualTo(18),
        reason: 'fewer entity keys than the eighteen that exist');
  });
}
