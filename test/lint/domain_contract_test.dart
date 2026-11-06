// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Docs-parity lint: a domain contract keeps the shape that lets an issue
// cite it and a reviewer check it (ADR 0048, #3335).
//
// A contract page names the commit it was checked against, declares its
// states before its transition table uses them, and points only at files
// that exist. Whether a rule is RIGHT stays with the review and with the
// tests the page's Evidence section names — this test refuses only a page
// that cannot be checked at all.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'lint_sources.dart';

const _root = 'docs/domain/contracts';

const _requiredSections = [
  '## Baseline',
  '## Concepts and identity',
  '## Relationships and cardinalities',
  '## States and transitions',
  '## Invariants',
  '## Processing',
  '## Evidence',
  '## Open decisions',
  '## Stop condition',
];

/// A backticked repository path: `supabase/…/x.sql`, `lib/…/y.dart`.
final _pathRef = RegExp(
  r'`((?:supabase|lib|test|docs|tool|scripts|packages|\.github)/'
  r'[A-Za-z0-9_./-]+\.[a-z0-9]+)`',
);

String _name(File f) => f.uri.pathSegments.last;

void main() {
  final pages = markdownFiles(_root, recursive: false)
      .where((f) => _name(f) != 'README.md')
      .toList();

  test('the convention and at least one contract exist', () {
    expect(File('$_root/README.md').existsSync(), isTrue,
        reason: '$_root/README.md defines the sections this test checks.');
    expect(pages, isNotEmpty,
        reason: 'ADR 0048 adopts the convention with a first page; '
            'an empty directory is a convention nobody uses.');
  });

  for (final page in pages) {
    final name = _name(page);
    final text = page.readAsStringSync();
    final lines = text.split('\n').map((l) => l.trimRight()).toList();

    test('$name: licence header, refs and every required section', () {
      expect(
        lines.first,
        '<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->',
        reason: '$name: first line must be the SPDX comment, like every '
            'other page under docs/.',
      );
      expect(text, matches(RegExp(r'- Refs: .*#\d+')),
          reason: '$name: the Baseline needs a "- Refs:" line naming the '
              'issue(s) the page serves.');
      expect(
        text,
        matches(RegExp(r'- Source commit: [0-9a-f]{40}\b')),
        reason: '$name: the Baseline needs "- Source commit: <40-hex>" — a '
            'short hash or a branch name is not a checked revision.',
      );
      for (final section in _requiredSections) {
        expect(lines, contains(section),
            reason: '$name: missing section "$section" '
                '(see $_root/README.md).');
      }
    });

    test('$name: every transition names declared states', () {
      final declaredLine = lines.firstWhere(
        (l) => l.startsWith('Declared states:'),
        orElse: () => '',
      );
      expect(declaredLine, isNotEmpty,
          reason: '$name: "Declared states: `a`, `b`, …" must precede the '
              'transition table.');
      final declared = RegExp(r'`([^`]+)`')
          .allMatches(declaredLine)
          .map((m) => m.group(1)!)
          .toSet();
      expect(declared, isNotEmpty, reason: '$name: no state is declared.');

      final start = lines.indexOf('## States and transitions');
      final end = lines.indexWhere((l) => l.startsWith('## '), start + 1);
      final section = lines.sublist(start, end < 0 ? lines.length : end);
      final rows = section
          .where((l) => l.startsWith('|'))
          .where((l) => !l.startsWith('| from |'))
          .where((l) => !RegExp(r'^\|\s*-').hasMatch(l))
          .toList();
      expect(rows, isNotEmpty,
          reason: '$name: no "| from | event | guard | to | effects |" '
              'rows.');

      for (final row in rows) {
        final cells = row.split('|').map((c) => c.trim()).toList();
        expect(cells.length, greaterThanOrEqualTo(6),
            reason: '$name: a transition row needs five cells: $row');
        for (final cell in [cells[1], cells[4]]) {
          // "(none)" is the initial pseudo-state; "*(…)*" is a replay
          // that answers whatever state the existing attempt is in.
          if (cell == '(none)' || cell.startsWith('*(')) continue;
          final state = cell.replaceAll('`', '');
          expect(declared, contains(state),
              reason: '$name: transition names the state "$state", which '
                  'is not in "Declared states": $row');
        }
      }
    });

    test('$name: every backticked repository path exists', () {
      for (final m in _pathRef.allMatches(text)) {
        final path = m.group(1)!;
        expect(File(path).existsSync(), isTrue,
            reason: '$name: points at $path, which does not exist — a '
                'contract that cites a file that moved sends the next '
                'reader to the wrong place.');
      }
    });
  }
}
