// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1582 — the matrix is a ratchet, not a table somebody once wrote.
//
// `matrix.dart` declares screens × axes; this file is the gate on that
// declaration, because every failure mode of a matrix is a failure of
// its LIST rather than of its assertions: a screen quietly dropped, an
// axis that stops being run while the row still claims it, or a gap
// with no reason — an absence wearing a row's clothes.
//
// "Count the thing, so a partial win is visible" — the convention
// `test/lint/layering_test.dart` set, applied to coverage. A pull
// request that widens ONE pump helper moves the count, visibly.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'matrix.dart';

/// Screens named in the matrix, measured or not. RATCHET: up only.
const _screenFloor = 16;

/// Screen × axis cells actually asserted. RATCHET: up only.
///
/// 65 of 90 on 2026-09-20 — #1583 brought the calendar hub's narrow,
/// largeText and reducedMotion cells in. The 25 missing are four
/// screens whose pump helper hard-codes its own viewport (24) and the
/// level canvas's keyboard cell, each named in `matrix.dart` with its
/// reason and date.
// #1653: Create workspace adds six measured cells.
const _cellFloor = 71;

/// Every gap reason carries the issue that owns it and the date it was
/// written, so a reason cannot rot unnoticed into a permanent excuse.
final _dated = RegExp(r'#\d+.*\(20\d\d-\d\d-\d\d\)');

void main() {
  test('the matrix only grows (#1582)', () {
    expect(kMatrix.length, greaterThanOrEqualTo(_screenFloor),
        reason: 'a screen left the matrix. Rows are added, not removed: a '
            'screen that stops being measured stays on the list with the '
            'reason it stopped');

    final measured = kMatrix.fold<int>(0, (n, row) => n + row.axes.length);
    expect(measured, greaterThanOrEqualTo(_cellFloor),
        reason: 'the matrix measures $measured cells, down from '
            '$_cellFloor. Raise the floor when it rises; never lower it '
            'to make a red run green');
  });

  test('every screen answers for every axis', () {
    for (final row in kMatrix) {
      for (final axis in MatrixAxis.values) {
        expect(row.covers(axis) || row.gaps.containsKey(axis), isTrue,
            reason: '${row.screen} says nothing about ${axis.name}');
      }
      expect(row.axes.isEmpty || row.pump != null, isTrue,
          reason: '${row.screen} claims axes with no pump to run them');
    }
  });

  test('every gap names an issue and a date', () {
    for (final row in kMatrix) {
      for (final entry in row.gaps.entries) {
        expect(_dated.hasMatch(entry.value), isTrue,
            reason: '${row.screen}/${entry.key.name}: "${entry.value}" is a '
                'gap without an issue and a date, which is an excuse');
      }
    }
  });

  // A row may claim an axis no file walks — the claim would then be
  // coverage on paper. The two walkers are read as text rather than
  // executed: each `matrixRowsFor(MatrixAxis.x)` call is the proof that
  // axis x is run over its rows.
  test('every axis a row claims is walked by a test file', () {
    final walked = <String>{};
    for (final path in const [
      'test/a11y/responsive_matrix_test.dart',
      'test/a11y/screen_guidelines_test.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final match
          in RegExp(r'matrixRowsFor\(MatrixAxis\.(\w+)\)').allMatches(source)) {
        walked.add(match.group(1)!);
      }
    }

    final claimed = {
      for (final row in kMatrix) ...row.axes.map((a) => a.name),
    };
    expect(claimed.difference(walked), isEmpty,
        reason: 'those axes are claimed by a row and walked by no test, so '
            'the matrix reports coverage nobody runs');
  });
}
