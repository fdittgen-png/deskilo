// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Docs-parity lint: a domain contract keeps the shape that lets an issue
// cite it and a reviewer check it (ADR 0048, #3335, #3571).
//
// A contract page states the rule that holds on master. It carries the
// seven sections the README's table lists, declares its transition
// table's states, uses existing files for the supported path references
// below, and holds no proposal text: a proposal, its open decisions and
// its stop condition live in the issue. Whether a rule is RIGHT stays
// with the review and with the tests the page's Evidence section names.
// These checks validate structure, not whether the implementation
// enforces the documented rules.

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
];

/// Pages that still carry proposal text from before the convention. They
/// are exempt from [_proposalError] ONLY: every other check still runs on
/// them. Each reconciliation removes its own name; the set only shrinks, a
/// new page is never listed, and there is no wildcard.
const _unreconciled = <String>{};

/// A refs line must be a real list item, not prose that contains one.
final _refsLine = RegExp(r'^- Refs: .*#\d+', multiLine: true);

final _proposedWord = RegExp(r'\bproposed\b', caseSensitive: false);

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

/// The reason a page is not a statement of shipped rules, or null.
String? _proposalError(List<String> lines) {
  for (final raw in lines) {
    final line = raw.trimRight();
    if (line == '## Open decisions') {
      return 'an "Open decisions" section belongs in the issue';
    }
    if (line == '## Stop condition') {
      return 'a "Stop condition" section belongs in the issue';
    }
    if (line.startsWith('- Source commit:')) {
      return 'a page pins no source commit';
    }
    if (_proposedWord.hasMatch(line)) {
      return 'the word "proposed" marks a plan, not a rule that holds: '
          '"$line"';
    }
  }
  return null;
}

/// The required headings a page lacks.
List<String> _missingSections(List<String> lines) =>
    [for (final s in _requiredSections) if (!lines.contains(s)) s];

/// The first-column labels of the first table under the README's section
/// heading, in order, without its header and separator rows.
List<String> _sectionTableLabels(List<String> lines) {
  final start = lines.indexOf('## What a page holds, and why in that order');
  if (start < 0) return const [];
  final labels = <String>[];
  for (final raw in lines.skip(start + 1)) {
    final line = raw.trim();
    if (line.startsWith('## ')) break;
    if (!line.startsWith('|')) {
      if (labels.isNotEmpty) break;
      continue;
    }
    labels.add(line.substring(1).split('|').first.trim());
  }
  return labels.length < 2 ? const [] : labels.sublist(2);
}

/// The lines of the States and transitions section, or an error naming the
/// page and the missing heading (never a RangeError from `sublist(-1)`).
({List<String>? section, String? error}) _transitionSection(
  List<String> lines,
  String name,
) {
  final start = lines.indexOf('## States and transitions');
  if (start < 0) {
    return (
      section: null,
      error: '$name: missing section "## States and transitions"',
    );
  }
  final end = lines.indexWhere((l) => l.startsWith('## '), start + 1);
  return (
    section: lines.sublist(start, end < 0 ? lines.length : end),
    error: null,
  );
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

  test('a valid seven-section page passes every structural check', () {
    final lines = [
      '<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->',
      '# Fixture',
      for (final s in _requiredSections) s,
      '- Refs: #3335',
      'Declared states: `a`, `b`',
      '| `a` | go | always | `b` | none |',
      'The fixture file `docs/domain/contracts/README.md` exists.',
    ];
    final text = lines.join('\n');
    expect(_missingSections(lines), isEmpty);
    expect(_refsLine.hasMatch(text), isTrue);
    expect(_proposalError(lines), isNull);
    expect(_transitionError(lines[lines.length - 2], {'a', 'b'}), isNull);
    expect(_missingPaths(text, File('$_root/fixture.md')), isEmpty);
  });

  test('a proposal marker is refused; current-rule text passes', () {
    expect(_proposalError(['A claim is accepted once the row is `sent`.']),
        isNull);
    expect(_proposalError(['An unproposed word is not the marker.']), isNull);
    for (final line in [
      'This rule is proposed for a later change.',
      'This rule is PROPOSED.',
      '**proposed:** a key',
      '## Open decisions',
      '## Open decisions   ',
      '## Stop condition',
      '- Source commit: 0e61749f2f0920a4117735bb416b98ce3919dc7e',
    ]) {
      expect(_proposalError(['fine', line, 'fine']), isNotNull, reason: line);
    }
  });

  test('an exemption skips the proposal check only', () {
    // The exemption is a filter on _proposalError alone: a missing heading,
    // an undeclared state and a missing file stay failures for any page.
    final lines = ['<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->'];
    expect(_missingSections(lines), _requiredSections);
    expect(_transitionError('| `x` | e | g | `y` | none |', {'a'}), isNotNull);
    expect(_missingPaths('`docs/__no_such_file__.md`', File('$_root/p.md')),
        ['docs/__no_such_file__.md']);
  });

  test('every exemption names an existing contract page', () {
    for (final name in _unreconciled) {
      expect(name, isNot('README.md'), reason: 'the README is never a page');
      expect(File('$_root/$name').existsSync(), isTrue,
          reason: '$name is in _unreconciled but is not a page under $_root: '
              'remove the stale entry.');
    }
  });

  test('the README section table equals the required sections, in order', () {
    final required = [for (final s in _requiredSections) s.substring(3)];
    final readme = File('$_root/README.md').readAsLinesSync();
    expect(_sectionTableLabels(readme), required);

    List<String> table(List<String> rows) => [
          '## What a page holds, and why in that order',
          '',
          '| Section | Meaning |',
          '|---|---|',
          for (final r in rows) '| $r | text |',
          '',
          '| Other | table |',
          '|---|---|',
          '| Extra | row |',
        ];
    expect(_sectionTableLabels(table(required)), required);
    expect(_sectionTableLabels(table(required.sublist(1))), isNot(required));
    expect(_sectionTableLabels(table([...required, 'Extra'])),
        isNot(required));
    expect(_sectionTableLabels(table([...required]..[0] = 'Renamed')),
        isNot(required));
    expect(_sectionTableLabels(table(required.reversed.toList())),
        isNot(required));
    expect(
        _sectionTableLabels(['| Other | table |', '|---|---|', '| a | b |']),
        isNot(required));
  });

  test('a refs line must be a list item; a missing heading is named', () {
    expect(_refsLine.hasMatch('Baseline\n- Refs: #3335 (text)'), isTrue);
    expect(_refsLine.hasMatch('This prose contains - Refs: #3335'), isFalse);
    final missing = _transitionSection(['## Baseline'], 'x.md');
    expect(missing.section, isNull);
    expect(missing.error, contains('x.md'));
    expect(missing.error, contains('## States and transitions'));
    final found = _transitionSection(
        ['## States and transitions', '| a |', '## Invariants'], 'x.md');
    expect(found.section, ['## States and transitions', '| a |']);
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
        reason: '$name: first line must be the SPDX comment.',
      );
      expect(_refsLine.hasMatch(text), isTrue,
          reason: '$name: the Baseline needs a list item "- Refs: #n" '
              'naming the issue(s) the page serves.');
      expect(_missingSections(lines), isEmpty,
          reason: '$name: missing required sections (see $_root/README.md).');
    });

    test('$name: states what holds, with no proposal text', () {
      if (_unreconciled.contains(name)) return;
      expect(_proposalError(lines), isNull,
          reason: '$name: a page states the rule that holds on master; a '
              'proposal lives in its issue ($_root/README.md).');
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

      final found = _transitionSection(lines, name);
      expect(found.error, isNull, reason: found.error);
      final rows = _transitionRows(found.section!).toList();
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
