// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4418 -- a wire vocabulary is an enum: no status, kind or resolution
// string is compared or switched on in presentation or application.
//
// A status, kind or resolution that arrives as text is decoded once, in the
// data layer (or on the domain row that carries it), into an enum with a
// named `unknown` (#3730's rule). A screen or command switches on the enum,
// so the compiler checks the switch and a value from the future reads as
// the neutral `unknown` instead of falling through a string comparison.
//
// This ratchet counts what is left: `== 'x'`, `!= 'x'`, `case 'x':` and
// `'x' =>` on a snake-case literal, in code lines (comments skipped) of every
// file under a `presentation/` or `application/` directory of lib/.
//
//  * a file listed in `wire_literal_compare_budget.txt` may not exceed its
//    count;
//  * a file not listed may not compare a wire literal at all;
//  * a count that fell must be recorded -- the budget only moves down.
//
// A file another lane owns keeps its count with an "owned by lane" note in
// the budget's header; the lane that owns it sweeps it.
//
// Record: `WIRE_LITERAL_BUDGET_WRITE=1 flutter test
// test/lint/wire_literal_compare_test.dart` rewrites the file from the tree
// (it refuses when a count grew).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

const _budgetFile = 'test/lint/wire_literal_compare_budget.txt';

/// The three spellings of a comparison on a snake-case literal.
final _compare = RegExp(r"[!=]= '([a-z_]+)'|case '([a-z_]+)':|'([a-z_]+)' =>");

/// Literals that are not a wire vocabulary, each with why.
const _allowed = <String, String>{
  'http': 'a URI scheme',
  'https': 'a URI scheme',
  'mailto': 'a URI scheme',
  'tel': 'a URI scheme',
  'deskilo': "the app's own URI scheme (invitation links)",
  'join': "the invitation link's URI host",
};

bool _inScope(String path) {
  final p = path.replaceAll('\\', '/');
  return (p.contains('/presentation/') || p.contains('/application/')) &&
      !p.endsWith('.g.dart') &&
      !p.endsWith('.freezed.dart');
}

/// Wire-literal comparisons in [lines], allowed literals not counted.
int countWireCompares(Iterable<String> lines) {
  var n = 0;
  for (final line in lines) {
    for (final m in _compare.allMatches(line)) {
      final lit = m.group(1) ?? m.group(2) ?? m.group(3);
      if (!_allowed.containsKey(lit)) n++;
    }
  }
  return n;
}

Map<String, int> _measure() {
  final out = <String, int>{};
  for (final f in filesUnder(['lib'])) {
    if (!_inScope(f.path)) continue;
    final n = countWireCompares(codeLines(f));
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

/// The header lines of the recorded file, kept on a rewrite (the
/// "owned by lane" notes live there).
List<String> _header() => File(_budgetFile).existsSync()
    ? [
        for (final line in File(_budgetFile).readAsLinesSync())
          if (line.startsWith('#')) line,
      ]
    : const [
        '# #4418 -- wire-literal comparisons per file under presentation/ and application/.',
        '# Only falls: test/lint/wire_literal_compare_test.dart explains and records.',
      ];

String _render(Map<String, int> counts) {
  final paths = counts.keys.toList()..sort();
  final sum = counts.values.fold<int>(0, (a, b) => a + b);
  return [
    ..._header().where((l) => !l.startsWith('# total ')),
    '# total $sum in ${counts.length} files',
    for (final p in paths) '${counts[p]} $p',
    '',
  ].join('\n');
}

void main() {
  test('the detector sees each spelling and skips an allowed literal', () {
    expect(
      countWireCompares([
        "if (row.status == 'pending') {}",
        "if (row.kind != 'credit_note') {}",
        "case 'under_accepted':",
        "'refunded' => l10n.x,",
        "if (uri.scheme == 'https') {}",
        "final s = 'not_a_compare';",
      ]),
      4,
    );
  });

  test('wire-literal comparisons: nothing grows, a fall is recorded', () {
    final actual = _measure();
    if (Platform.environment['WIRE_LITERAL_BUDGET_WRITE'] == '1') {
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
          '${e.key}: ${e.value} wire-literal comparisons and no budget -- '
          'decode the value into an enum with a named unknown in the data '
          'layer and switch on the enum',
        );
      } else if (e.value > budget) {
        failures.add('${e.key}: ${e.value} comparisons, budget $budget');
      } else if (e.value < budget) {
        failures.add(
          '${e.key}: fell from $budget to ${e.value} -- record it '
          '(WIRE_LITERAL_BUDGET_WRITE=1)',
        );
      }
    }
    for (final p in recorded.keys) {
      if (!actual.containsKey(p)) {
        failures.add('$p: none left -- record it (WIRE_LITERAL_BUDGET_WRITE=1)');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
