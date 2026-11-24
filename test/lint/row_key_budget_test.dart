// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4423 -- a row key is read where the row is read. A column named as a
// literal subscript (`row['status']`) belongs to the data layer: the row
// mapper of a `data/` directory, or a `domain/*from_json*` reader. Anywhere
// else the screen, the command or the provider reads a server row by its
// column name, and a renamed column breaks it silently.
//
// This ratchet counts what is left outside those places, per file, in code
// lines (comments skipped):
//
//  * a file listed in `row_key_budget.txt` may not exceed its count;
//  * a file not listed may not subscript a row by a literal key;
//  * a count that fell must be recorded -- the budget only moves down.
//
// Record: `ROW_KEY_BUDGET_WRITE=1 flutter test test/lint/row_key_budget_test.dart`
// rewrites the file from the tree (it refuses when a count grew).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';
import 'literal_ratchet.dart' show codeLines;

const _budgetFile = 'test/lint/row_key_budget.txt';

/// `x['snake_case']`: a literal key subscript.
final _rowKey = RegExp(r"\[\s*'([a-z][a-z0-9_]*)'\s*\]");

/// Whether [path] is where a row is read: a data layer, or a domain reader
/// of a server row.
bool isRowReader(String path) {
  final p = path.replaceAll('\\', '/');
  if (p.contains('/data/')) return true;
  return p.contains('/domain/') && p.split('/').last.contains('from_json');
}

/// Literal row-key subscripts in [lines].
int countRowKeys(Iterable<String> lines) =>
    lines.fold(0, (sum, line) => sum + _rowKey.allMatches(line).length);

Map<String, int> _measure() {
  final out = <String, int>{};
  final files = handWrittenDartFiles('lib').toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    if (isRowReader(f.path)) continue;
    final n = countRowKeys(codeLines(f));
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
  final sum = counts.values.fold<int>(0, (a, b) => a + b);
  return [
    '# #4423 -- literal row-key subscripts per file outside data/ and domain/*from_json*.',
    '# Only falls: test/lint/row_key_budget_test.dart explains and records.',
    '# total $sum in ${counts.length} files',
    for (final p in paths) '${counts[p]} $p',
    '',
  ].join('\n');
}

void main() {
  test('the detector counts a literal key and leaves the row readers out', () {
    expect(
      countRowKeys([
        "final s = row['status'] as String;",
        "out['total_cents'] = 1; m[key] = 2; list[0];",
        "final t = row[\"Mixed\"];",
      ]),
      2,
    );
    expect(isRowReader('lib/features/money/data/supabase_x.dart'), isTrue);
    expect(isRowReader('lib/features/money/domain/invoice_from_json.dart'), isTrue);
    expect(isRowReader('lib/features/money/domain/invoice.dart'), isFalse);
    expect(isRowReader('lib/features/money/presentation/x.dart'), isFalse);
  });

  test('row keys outside the data layer: nothing grows, a fall is recorded', () {
    final actual = _measure();
    if (Platform.environment['ROW_KEY_BUDGET_WRITE'] == '1') {
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
          '${e.key}: ${e.value} literal row keys and no budget -- read the '
          'row in its data layer and hand this file a typed value',
        );
      } else if (e.value > budget) {
        failures.add('${e.key}: ${e.value} row keys, budget $budget');
      } else if (e.value < budget) {
        failures.add(
          '${e.key}: fell from $budget to ${e.value} -- record it '
          '(ROW_KEY_BUDGET_WRITE=1)',
        );
      }
    }
    for (final p in recorded.keys) {
      if (!actual.containsKey(p)) {
        failures.add('$p: none left -- record it (ROW_KEY_BUDGET_WRITE=1)');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
