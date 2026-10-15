// SPDX-License-Identifier: AGPL-3.0-or-later
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
import '../helpers/lint/configuration_classification.dart' show deployableEntityKeys, workspaceColumns;

const _matrix = 'docs/domain/CONFIGURATION_MATRIX.md';






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
    final first = cells[1]
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
