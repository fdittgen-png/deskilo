// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3215 -- the rows that still put the help symbol INSIDE the title
// (`HelpDotTitle(`) only fall.
//
// `HelpDotTitle` places the symbol at the end of the title area, so its x
// position follows whatever trails the row and the symbols of a list do not
// share a column (#3068, #3072). `HelpRow` (lib/core/ui/help_row.dart) keeps
// the symbol in a fixed trailing slot. Settings and Payments & billing moved
// first; this ratchet counts the rest so the migration is measured:
//
//  * a file listed in `help_dot_title_budget.txt` may not exceed its count;
//  * a file not listed may not use `HelpDotTitle(` at all -- a new row uses
//    `HelpRow`;
//  * a count that fell must be recorded -- a partial win is visible, and the
//    budget can only move down.
//
// Record: `HELP_TITLE_BUDGET_WRITE=1 flutter test
// test/lint/help_dot_title_budget_test.dart` rewrites the file from the tree
// (it never raises a budget on its own: it refuses when a count grew).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

const _budgetFile = 'test/lint/help_dot_title_budget.txt';
const _widgetFile = 'lib/core/help/help_dot.dart';
final _use = RegExp(r'\bHelpDotTitle\(');

Map<String, int> _measure() {
  final out = <String, int>{};
  for (final f in filesUnder(['lib'])) {
    if (f.path == _widgetFile || f.path.endsWith('.g.dart')) continue;
    final n = codeLines(f)
        .fold<int>(0, (sum, line) => sum + _use.allMatches(line).length);
    if (n > 0) out[f.path] = n;
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
    '# #3215 -- rows with the help symbol inside the title (HelpDotTitle) per file.',
    '# Only falls: test/lint/help_dot_title_budget_test.dart explains and records.',
    for (final p in paths) '${counts[p]} $p',
    '',
  ].join('\n');
}

void main() {
  test('HelpDotTitle rows: nothing grows, a fall is recorded', () {
    final actual = _measure();
    if (Platform.environment['HELP_TITLE_BUDGET_WRITE'] == '1') {
      final old = File(_budgetFile).existsSync() ? _recorded() : <String, int>{};
      final grew = [
        for (final e in actual.entries)
          if (old.containsKey(e.key) && e.value > old[e.key]!) e.key,
        for (final e in actual.entries)
          if (old.isNotEmpty && !old.containsKey(e.key)) e.key,
      ];
      expect(grew, isEmpty, reason: 'a budget is never raised by recording: $grew');
      File(_budgetFile).writeAsStringSync(_render(actual));
      return;
    }
    final recorded = _recorded();
    final failures = <String>[];
    for (final e in actual.entries) {
      final budget = recorded[e.key];
      if (budget == null) {
        failures.add(
          '${e.key}: ${e.value} HelpDotTitle rows and no budget -- use HelpRow',
        );
      } else if (e.value > budget) {
        failures.add('${e.key}: ${e.value} rows, budget $budget');
      } else if (e.value < budget) {
        failures.add(
          '${e.key}: fell from $budget to ${e.value} -- record it '
          '(HELP_TITLE_BUDGET_WRITE=1)',
        );
      }
    }
    for (final p in recorded.keys) {
      if (!actual.containsKey(p)) {
        failures.add('$p: no HelpDotTitle left -- record it (HELP_TITLE_BUDGET_WRITE=1)');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
