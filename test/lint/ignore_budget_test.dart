// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2389 — an `// ignore:` switches a rule off for one line, and the
// rules are only worth having while the switches stay few and explained.
// A new ignore says why and names the issue that removes it
// (`// ignore: rule — why, #NNNN`); the ones from before this ratchet
// only go down.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// `// ignore:` comments in hand-written lib/ (26 when the budget began,
/// none of them naming an issue).
const _ignoreBudget = 26;

/// Of those, the ones that name no issue (`#NNNN`).
const _unexplainedBudget = 26;

void main() {
  final ignore = RegExp(r'//\s*ignore(_for_file)?:');
  final hits = scanLines(
    handWrittenDartFiles('lib'),
    ignore.hasMatch,
    skipComments: false,
  );
  final unexplained = hits.where((h) => !RegExp(r'#\d+').hasMatch(h)).toList();

  test('the ignore count only goes down (ratchet)', () {
    expect(
      hits.length,
      lessThanOrEqualTo(_ignoreBudget),
      reason:
          'answer the rule instead of switching it off:\n'
          '${hits.join('\n')}',
    );
    expect(
      hits.length,
      _ignoreBudget,
      reason:
          'fewer ignores than the budget: lower _ignoreBudget to '
          '${hits.length} so the win stays',
    );
  });

  test('a new ignore names the issue that removes it', () {
    expect(
      unexplained.length,
      lessThanOrEqualTo(_unexplainedBudget),
      reason:
          'write "// ignore: rule — why, #NNNN":\n'
          '${unexplained.join('\n')}',
    );
    expect(
      unexplained.length,
      _unexplainedBudget,
      reason:
          'fewer unexplained ignores than the budget: lower '
          '_unexplainedBudget to ${unexplained.length}',
    );
  });
}
