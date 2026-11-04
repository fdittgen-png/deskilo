// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2603: measure per-file pumpAndSettle calls without rejecting a needed
// interaction test solely for cost. Reviewed growth records its previous and
// new count, preserved invariant and cost rationale; reductions remain visible.
// PUMP_BUDGET_WRITE=1 records reductions and explicitly reviewed growth only.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

/// Files with at least this many calls are listed.
const _threshold = 10;
const _budgetFile = 'test/lint/pump_and_settle_budget.txt';
final _call = RegExp(r'\bpumpAndSettle\(');

class _ReviewedGrowth {
  const _ReviewedGrowth(this.before, this.after, this.invariant, this.cost);
  final int before;
  final int after;
  final String invariant;
  final String cost;
}

// Add a specific, reviewed interaction invariant and measured cost here when
// raising a recorded count; before=0 denotes an untracked file below threshold,
// not a measured zero. Never add a blanket allowance. Remove an entry
// after recording the new baseline: the writer preserves its rationale in the
// baseline file as a retained, validated audit comment.
const _reviewedGrowth = <String, _ReviewedGrowth>{};

List<String> _growthFailures(
  Map<String, int> actual,
  Map<String, int> old,
  Map<String, _ReviewedGrowth> reviewed,
) {
  final failures = <String>[];
  for (final e in actual.entries) {
    final before = old[e.key] ?? 0;
    if (e.value <= before) continue;
    final approval = reviewed[e.key];
    if (approval == null ||
        approval.before != before ||
        approval.after != e.value ||
        approval.invariant.trim().isEmpty ||
        approval.cost.trim().isEmpty) {
      final baseline = old.containsKey(e.key)
          ? '$before'
          : 'below $_threshold (untracked)';
      failures.add(
        '${e.key}: grew from $baseline to ${e.value}; record the '
        'reviewed interaction invariant and cost',
      );
    }
  }
  for (final e in reviewed.entries) {
    if ((old[e.key] ?? 0) != e.value.before ||
        actual[e.key] != e.value.after ||
        e.value.after <= e.value.before) {
      failures.add('${e.key}: stale or invalid reviewed growth');
    }
  }
  return failures;
}

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

Map<String, int> _recorded(List<String> lines) {
  final out = <String, int>{};
  for (final line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split(' ');
    if (parts.length < 2 || parts.sublist(1).join(' ').isEmpty) {
      throw const FormatException('Malformed pump baseline');
    }
    final path = parts.sublist(1).join(' ');
    if (out.containsKey(path)) {
      throw const FormatException('Duplicate pump baseline');
    }
    final count = int.parse(parts.first);
    if (count < _threshold) {
      throw const FormatException('Invalid pump baseline');
    }
    out[path] = count;
  }
  return out;
}

List<Map<String, dynamic>> _audit(List<String> lines) {
  final records = <Map<String, dynamic>>[];
  for (final line in lines.where((line) => line.startsWith('# review'))) {
    if (!line.startsWith('# review ')) {
      throw const FormatException('Malformed pump review record');
    }
    final value = jsonDecode(line.substring('# review '.length));
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference({
          'path',
          'before',
          'after',
          'invariant',
          'cost',
        }).isNotEmpty ||
        value.length != 5 ||
        value['path'] is! String ||
        (value['path'] as String).trim().isEmpty ||
        value['before'] is! int ||
        value['after'] is! int ||
        (value['before'] as int) < 0 ||
        (value['after'] as int) <= (value['before'] as int) ||
        value['invariant'] is! String ||
        (value['invariant'] as String).trim().isEmpty ||
        value['cost'] is! String ||
        (value['cost'] as String).trim().isEmpty) {
      throw const FormatException('Malformed pump review record');
    }
    records.add(value);
  }
  return records;
}

String _render(
  Map<String, int> counts,
  List<Map<String, dynamic>> history,
  Map<String, _ReviewedGrowth> reviewed,
) {
  final paths = counts.keys.toList()..sort();
  final records = [
    ...history,
    for (final entry in reviewed.entries)
      {
        'path': entry.key,
        'before': entry.value.before,
        'after': entry.value.after,
        'invariant': entry.value.invariant,
        'cost': entry.value.cost,
      },
  ];
  return [
    '# #2603 -- pumpAndSettle calls per test file (files with $_threshold or more).',
    '# Reviewed interaction growth and reductions: see pump_and_settle_budget_test.dart.',
    for (final record in records) '# review ${jsonEncode(record)}',
    for (final p in paths) '${counts[p]} $p',
    '',
  ].join('\n');
}

void main() {
  test('reviewed growth requires matching invariant and cost', () {
    const valid = _ReviewedGrowth(
      10,
      11,
      'retry state remains visible',
      'one pump per retry',
    );
    expect(_growthFailures({'a': 11}, {'a': 10}, {'a': valid}), isEmpty);
    expect(_growthFailures({'a': 11}, {'a': 10}, {}), isNotEmpty);
    expect(_growthFailures({'a': 12}, {'a': 10}, {'a': valid}), isNotEmpty);
    expect(
      _growthFailures({'a': 11}, {'a': 10}, {
        'a': const _ReviewedGrowth(10, 11, '', 'one pump'),
      }),
      isNotEmpty,
    );
    expect(_growthFailures({'a': 11}, {'a': 11}, {'a': valid}), isNotEmpty);
    final temp = Directory.systemTemp.createTempSync('pump-growth');
    addTearDown(() => temp.deleteSync(recursive: true));
    final baseline = File('${temp.path}/budget.txt')
      ..writeAsStringSync(_render({'a': 11}, [], {'a': valid}));
    final written = baseline.readAsLinesSync();
    expect(_recorded(written), {'a': 11});
    expect(_growthFailures({'a': 11}, _recorded(written), {}), isEmpty);
    expect(_audit(written).single, {
      'path': 'a',
      'before': 10,
      'after': 11,
      'invariant': 'retry state remains visible',
      'cost': 'one pump per retry',
    });
    final rewritten = _render({'a': 11}, _audit(written), {}).split('\n');
    expect(_audit(rewritten), _audit(written));
    expect(() => _audit(['# review {bad']), throwsFormatException);
    expect(() => _audit(['# review {}']), throwsFormatException);
    expect(() => _audit(['# review']), throwsFormatException);
    expect(() => _recorded(['-1 a']), throwsFormatException);
    expect(_growthFailures({'a': 10}, {}, {}), isNotEmpty);
    expect(_growthFailures({'a': 9}, {'a': 10}, {}), isEmpty);
    expect(
      _growthFailures({'a': 11}, {'a': 10}, {
        'a': const _ReviewedGrowth(10, 11, 'retry shown', ''),
      }),
      isNotEmpty,
    );
  });

  test('pumpAndSettle growth is reviewed and a fall is recorded', () {
    final actual = _measure();
    if (Platform.environment['PUMP_BUDGET_WRITE'] == '1') {
      final lines = File(_budgetFile).existsSync()
          ? File(_budgetFile).readAsLinesSync()
          : <String>[];
      final old = _recorded(lines);
      final history = _audit(lines);
      final failures = _growthFailures(actual, old, _reviewedGrowth);
      expect(failures, isEmpty, reason: failures.join('\n'));
      File(_budgetFile)
          .writeAsStringSync(_render(actual, history, _reviewedGrowth));
      return;
    }
    final lines = File(_budgetFile).readAsLinesSync();
    final recorded = _recorded(lines);
    _audit(lines);
    final failures = _growthFailures(actual, recorded, _reviewedGrowth);
    for (final e in actual.entries) {
      final budget = recorded[e.key];
      if (budget == null || e.value > budget) {
        // Growth is checked against explicit reviewed invariants above.
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
