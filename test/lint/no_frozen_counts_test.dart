// SPDX-License-Identifier: 0BSD
//
// #1334 — the orientation documents may not carry a count of the
// repository, because a count in prose is wrong by the next merge.
//
// `docs/PROJECT_OVERVIEW.md` said 73 migrations, 21 feature flags, 944
// ARB keys and 1 013 test cases. The repository went past 250, 108,
// 3 400 and 3 900 without one of those lines changing, and a reader had
// no way to tell which to distrust. Every one of them was written in
// good faith by somebody who had just counted.
//
// So the rule is not "keep them up to date" — nobody can. It is that
// these documents name the command and let it answer:
//
//     dart run tool/project_scale.dart     the repository's size
//     dart run tool/test_inventory.dart    the suite, by layer
//
// Scope: the documents a newcomer reads to orient themselves. A release
// note, an ADR or an issue body is a statement about a moment and may
// hold whatever number was true then — those are history, and history is
// allowed to be dated.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The documents this rule governs, and why each one is in the list.
const Map<String, String> _oriented = {
  'docs/PROJECT_OVERVIEW.md': 'the document a new reader opens first',
  'CONTRIBUTING.md': 'what a contributor is told before their first PR',
  'docs/wiki/Implementation.md': 'the engineering overview in the wiki',
  'docs/AGENT_RULES.md': 'the rules an agent reads every session',
};

/// The nouns whose count rots. Each is something `project_scale` or the
/// test inventory measures, so a number in front of one is an answer
/// somebody should have asked the tool for.
const List<String> _counted = [
  'migrations',
  'migration files',
  'feature flags',
  'features',
  'ARB keys',
  'translation keys',
  'test cases',
  'test files',
  'tests',
  'routes',
  'workflows',
  'Dart source files',
  'source files',
];

/// `1 013 test cases`, `73 migrations`, `~50 lint tests`, `108 flags`.
/// The thousands separator may be a space or a comma, and an approximate
/// number is still a number that rots.
final _frozen = RegExp(
  r'(?<!#)\b~?(\d{1,3}(?:[  ,]\d{3})+|\d{2,})\s+(?:'
  '${_counted.map(RegExp.escape).join('|')}'
  r')\b',
  caseSensitive: false,
);

/// The other shape the rot took: a table row naming the thing in one
/// cell and its count in the next. That is exactly how the overview's
/// "Current scale" table was written, so a rule that only reads prose
/// would have let the whole table back in.
final _frozenCell = RegExp(
  r'^\|[^|]*\b(?:'
  '${_counted.map(RegExp.escape).join('|')}'
  r')\b[^|]*\|\s*~?\d[\d  ,]*\s*(?:[(×]|\|)',
  caseSensitive: false,
);

/// A heading may open a section that is allowed to hold counts, by
/// saying when they were true: `<!-- dated: YYYY-MM-DD — why -->`. A
/// record of what was corrected in August is history, and history is
/// allowed to be dated; a claim about today is not.
final _dated = RegExp(r'<!--\s*dated:\s*\d{4}-\d{2}-\d{2}');

/// Lines that are allowed to hold one, because they are the argument for
/// the rule rather than a claim about today.
bool _exempt(String line) =>
    line.contains('#1334') ||
    line.contains('project_scale') ||
    line.contains('test_inventory');

void main() {
  test('the orientation documents exist', () {
    for (final path in _oriented.keys) {
      expect(File(path).existsSync(), isTrue,
          reason: '$path (${_oriented[path]}) is gone — either this lint '
              'is measuring a document that moved, or the document a '
              'newcomer reads has disappeared');
    }
  });

  test('none of them freezes a count of the repository', () {
    final offences = <String>[];
    for (final entry in _oriented.entries) {
      final lines = File(entry.key).readAsLinesSync();
      var datedSection = false;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.startsWith('#')) datedSection = false;
        if (_dated.hasMatch(line)) datedSection = true;
        if (datedSection || _exempt(line)) continue;
        final match =
            _frozen.firstMatch(line) ?? _frozenCell.firstMatch(line);
        if (match != null) {
          offences.add('${entry.key}:${i + 1}  ${match.group(0)}');
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason: 'these lines state how many of something the repository '
          'has:\n  ${offences.join('\n  ')}\n\n'
          'A count in prose is wrong by the next merge, and a reader '
          'cannot tell which line went stale. Name the command instead:\n'
          '  dart run tool/project_scale.dart    (size)\n'
          '  dart run tool/test_inventory.dart   (the suite, by layer)\n'
          'A sentence that exists to explain THIS rule may keep its '
          'numbers — cite #1334 on the line.',
    );
  });

  test('the pattern catches the counts that actually went stale', () {
    // Red-first, kept: these are the exact strings the overview carried
    // before #1334, so a future edit that weakens the pattern fails here
    // rather than silently letting them back in.
    for (final was in [
      '| SQL migrations in the repo | 73 (`0001` … `0073`) |',
      '| Toggleable per-workspace features | 21 |',
      '| ARB translation keys per locale | 944 × 5 locales |',
      '**70 % unit / 20 % widget / 10 % integration.** 1 013 test cases '
          'across 161 files.',
      'Ten workflows in `.github/workflows/`. 16 workflows now.',
    ]) {
      expect(_frozen.hasMatch(was) || _frozenCell.hasMatch(was), isTrue,
          reason: 'this line used to sit in the overview and is exactly '
              'what the rule exists to refuse: "$was"');
    }
  });

  test('it does not fire on an issue number, a version or a percentage', () {
    for (final fine in [
      'Closes #1013 and #161.',
      'Flutter **3.41.9** stable (`FLUTTER_VERSION` in every workflow)',
      '`domain/` 85 %, `presentation/` 80 %, `lib/core/` 75 %',
      'One registry-touching branch at a time.',
      'PRs under 400 non-generated lines.',
      'Migration 0251 registers the entity.',
    ]) {
      expect(_frozen.hasMatch(fine) || _frozenCell.hasMatch(fine), isFalse,
          reason: 'a lint that cries wolf is one people learn to skip: '
              '"$fine"');
    }
  });
}
