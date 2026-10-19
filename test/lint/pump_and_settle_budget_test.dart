// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2603 (T4 of #2599) -- `pumpAndSettle` per test file only falls.
//
// A screen test that settles after every tap proves a decision through the
// whole widget tree: slow, and the first thing to flake. Measured on
// 2026-10-19: 3,650 calls across the suite, 104 in one file. A decision that
// becomes an object is proved by a table test on that object, and its screen
// keeps one wiring test per surface (#2494); this ratchet records how far
// each file has come.
//
//  * a file listed in `pump_and_settle_budget.txt` may not exceed its count;
//  * a file not listed may not reach the threshold (a new heavy file is a
//    decision to make, not a number to record);
//  * a count that fell must be recorded -- a partial win is visible, and the
//    budget can only move down.
//
// Record: `PUMP_BUDGET_WRITE=1 flutter test test/lint/pump_and_settle_budget_test.dart`
// rewrites the file from the tree (it never raises a budget on its own: it
// refuses to when a count grew).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

/// Files with at least this many calls are listed.
const _threshold = 10;
const _budgetFile = 'test/lint/pump_and_settle_budget.txt';
final _call = RegExp(r'\bpumpAndSettle\(');

Map<String, int> _measure() {
  final out = <String, int>{};
  for (final f in filesUnder(['test'])) {
    if (!f.path.endsWith('_test.dart')) continue;
    final n = codeLines(f)
        .where(_call.hasMatch)
        .fold<int>(0, (sum, line) => sum + _call.allMatches(line).length);
    if (n >= _threshold) out[f.path] = n;
  }
  return out;
}

Map<String, int> _recorded() {
  final out = <String, int>{};
  for (final line in File(_budgetFile).readAsLinesSync()) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split(' ');
    out[parts.sublist(1).join(' ')] = int.parse(parts.first);
  }
  return out;
}

String _render(Map<String, int> counts) {
  final paths = counts.keys.toList()..sort();
  return [
    '# #2603 -- pumpAndSettle calls per test file (files with $_threshold or more).',
    '# Only falls: test/lint/pump_and_settle_budget_test.dart explains and records.',
    for (final p in paths) '${counts[p]} $p',
    '',
  ].join('\n');
}

void main() {
  test('pumpAndSettle per test file: nothing grows, a fall is recorded', () {
    final actual = _measure();
    if (Platform.environment['PUMP_BUDGET_WRITE'] == '1') {
      final old = File(_budgetFile).existsSync()
          ? _recorded()
          : <String, int>{};
      final grew = [
        for (final e in actual.entries)
          if (old.containsKey(e.key) && e.value > old[e.key]!) e.key,
        for (final e in actual.entries)
          if (old.isNotEmpty && !old.containsKey(e.key)) e.key,
      ];
      expect(
        grew,
        isEmpty,
        reason: 'a budget is never raised by recording: $grew',
      );
      File(_budgetFile).writeAsStringSync(_render(actual));
      return;
    }
    final recorded = _recorded();
    final failures = <String>[];
    for (final e in actual.entries) {
      final budget = recorded[e.key];
      if (budget == null) {
        failures.add(
          '${e.key}: ${e.value} pumpAndSettle calls and no budget -- prove the '
          'rule on an object with a table test, or settle less',
        );
      } else if (e.value > budget) {
        failures.add('${e.key}: ${e.value} calls, budget $budget');
      } else if (e.value < budget) {
        failures.add(
          '${e.key}: fell from $budget to ${e.value} -- record it '
          '(PUMP_BUDGET_WRITE=1)',
        );
      }
    }
    for (final p in recorded.keys) {
      if (!actual.containsKey(p)) {
        failures.add(
          '$p: no longer at $_threshold calls -- record it (PUMP_BUDGET_WRITE=1)',
        );
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
