// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Docs-parity lint: a domain contract keeps the shape that lets an issue
// cite it and a reviewer check it (ADR 0048, #3335).
//
// A contract page names a source revision, declares its table's states,
// and uses existing files for the supported path references below.
// Whether a rule is RIGHT stays with the review and with the tests the
// page's Evidence section names. These checks validate structure, not
// whether the implementation enforces the documented rules.

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

/// A backticked repository path or a peer Markdown filename (also `./peer.md`).
final _pathRef = RegExp(
  r'`((?:supabase|lib|test|docs|tool|scripts|packages|\.github)/'
  r'[A-Za-z0-9_./-]+\.[a-z0-9]+|(?:\./)?[A-Za-z0-9_.-]+\.md)`',
);

String _name(File f) => f.uri.pathSegments.last;

List<String> _tableCells(String row) => row.length < 2
    ? const []
    : row.substring(1, row.length - 1)
        .split('|').map((c) => c.trim()).toList();

bool _isTableDecoration(String row) {
  if (!row.startsWith('|') || !row.endsWith('|')) return false;
  final cells = _tableCells(row);
  if (cells.length != 5) return false;
  return cells.join('|') == 'from|event|guard|to|effects' ||
      cells.every((c) => RegExp(r'^:?-{3,}:?$').hasMatch(c));
}

Iterable<String> _transitionRows(Iterable<String> lines) => lines
    .map((l) => l.trim())
    .where((l) => l.contains('|') && !_isTableDecoration(l));

String? _transitionError(String row, Set<String> declared) {
  if (!row.startsWith('|') || !row.endsWith('|')) {
    return 'a transition row needs leading and trailing pipes';
  }
  final cells = _tableCells(row);
  if (cells.length != 5 || cells.any((c) => c.isEmpty)) {
    return 'a transition row needs five nonempty cells';
  }
  for (final cell in [cells[0], cells[3]]) {
    // Initial pseudo-state or a replay answering the existing attempt's state.
    if (cell == '(none)' || cell.startsWith('*(')) continue;
    final state = cell.replaceAll('`', '');
    if (!declared.contains(state)) return 'undeclared state "$state"';
  }
  return null;
}

Iterable<String> _missingPaths(String text, File page) sync* {
  for (final m in _pathRef.allMatches(text)) {
    final path = m.group(1)!;
    final local = !path.contains('/') || path.startsWith('./');
    final file = File(local ? '${page.parent.path}/$path' : path);
    if (!file.existsSync()) yield path;
  }
}

void main() {
  test('transition fixtures require five nonempty cells and known states', () {
    const states = {'prepared', 'sent'};
    expect(_transitionError(
        '| `prepared` | claim | allowed | `sent` | post |', states), isNull);
    for (final row in [
      '| `prepared` | claim | allowed | `sent` |',
      '| `prepared` | claim | allowed | `sent` | post | extra |',
      '| `prepared` | | allowed | `sent` | post |',
      '| `prepared` | claim | | `sent` | post |',
      '| `prepared` | claim | allowed | `sent` | |',
      '| `prepared` | claim | allowed | `unknown` | post |',
      '| `prepared` | claim | allowed | `sent` | post',
    ]) {
      expect(_transitionError(row, states), isNotNull, reason: row);
    }
  });

  test('table scan retains malformed rows and skips decorations', () {
    const valid = '| `prepared` | claim | allowed | `sent` | post |';
    const malformed = '`prepared` | claim | allowed | `sent` | post |';
    final rows = _transitionRows([
      '|from|event|guard|to|effects|',
      '|---|---|---|---|---|',
      '| :--- | ---: | :---: | --- | --- |',
      valid, malformed, '|---|---|---|---|',
    ]).toList();
    expect(rows, [valid, malformed, '|---|---|---|---|']);
    expect(_transitionError(rows[1], {'prepared', 'sent'}), isNotNull);
  });

  test('root and peer references reject missing files', () {
    const text = '`docs/domain/contracts/README.md` `README.md` `./README.md` '
        '`__missing_contract_fixture__.md` '
        '`docs/domain/contracts/__missing_contract_fixture__.md`';
    expect(_missingPaths(text, File('$_root/fixture.md')), [
      '__missing_contract_fixture__.md',
      'docs/domain/contracts/__missing_contract_fixture__.md',
    ]);
  });

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

    test('$name: every transition has five cells and declared states', () {
      final declaredLine = lines.firstWhere(
        (l) => l.startsWith('Declared states:'),
        orElse: () => '',
      );
      expect(declaredLine, isNotEmpty,
          reason: '$name: "Declared states: `a`, `b`, …" must list the '
              'table\'s states.');
      final declared = RegExp(r'`([^`]+)`')
          .allMatches(declaredLine)
          .map((m) => m.group(1)!)
          .toSet();
      expect(declared, isNotEmpty, reason: '$name: no state is declared.');

      final start = lines.indexOf('## States and transitions');
      final end = lines.indexWhere((l) => l.startsWith('## '), start + 1);
      final section = lines.sublist(start, end < 0 ? lines.length : end);
      final rows = _transitionRows(section).toList();
      expect(rows, isNotEmpty,
          reason: '$name: no "| from | event | guard | to | effects |" '
              'rows.');

      for (final row in rows) {
        expect(_transitionError(row, declared), isNull, reason: '$name: $row');
      }
    });

    test('$name: supported backticked file references exist', () {
      expect(_missingPaths(text, page), isEmpty,
          reason: '$name: a referenced file moved or does not exist.');
    });
  }
}
