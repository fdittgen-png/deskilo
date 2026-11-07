// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3338 (of #3328) -- the removability acceptance map is a ratchet, not a
// claim: every test it cites exists, a covered row cites at least one, a row
// that is not covered says what remains, and the number of such rows is
// written in the map itself (docs/design/REMOVABILITY_ACCEPTANCE.md) and has
// to equal the count -- a win lowers it, a regression cannot hide.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _path = 'docs/design/REMOVABILITY_ACCEPTANCE.md';

typedef _Row = ({
  int number,
  List<String> tests,
  String state,
  String remaining,
});

List<_Row> _rows(String text) {
  final rows = <_Row>[];
  for (final line in text.split('\n')) {
    if (!RegExp(r'^\| \d+ \|').hasMatch(line)) continue;
    final cells = line.split('|').map((c) => c.trim()).toList();
    // | # | scenario | owner | tests | state | remaining |
    rows.add((
      number: int.parse(cells[1]),
      tests: [
        for (final m in RegExp(r'`([^`]+)`').allMatches(cells[4])) m.group(1)!,
      ],
      state: cells[5],
      remaining: cells[6],
    ));
  }
  return rows;
}

void main() {
  final text = File(_path).readAsStringSync();
  final rows = _rows(text);

  test('the map has the ten rows of the issue and the rows #3337 doubted', () {
    expect([for (final r in rows) r.number], [for (var i = 1; i <= 13; i++) i]);
  });

  test('every cited test exists', () {
    final missing = [
      for (final r in rows)
        for (final t in r.tests)
          if (!File(t).existsSync()) 'row ${r.number}: $t',
    ];
    expect(missing, isEmpty);
  });

  test('a cited script is run by a workflow, not only present', () {
    final workflows = [
      for (final f in filesWithExtension('.github/workflows', '.yml'))
        f.readAsStringSync(),
    ].join('\n');
    final unrun = [
      for (final r in rows)
        for (final t in r.tests)
          if (t.endsWith('.sh') && !workflows.contains(t))
            'row ${r.number}: $t',
    ];
    expect(unrun, isEmpty, reason: 'a script no workflow runs proves nothing');
  });

  test('a covered row cites a test; any other row says what remains', () {
    for (final r in rows) {
      expect(
        const {'covered', 'partial', 'open'},
        contains(r.state),
        reason: 'row ${r.number}',
      );
      if (r.state == 'covered') {
        expect(r.tests, isNotEmpty, reason: 'row ${r.number} cites nothing');
        expect(r.remaining, isEmpty, reason: 'row ${r.number}');
      } else {
        expect(r.remaining, isNotEmpty, reason: 'row ${r.number} is silent');
      }
    }
  });

  test('the count of rows that are not covered is the number in the map', () {
    final stated = int.parse(
      RegExp(
        r'^Open rows: (\d+)$',
        multiLine: true,
      ).firstMatch(text)!.group(1)!,
    );
    final actual = rows.where((r) => r.state != 'covered').length;
    expect(
      actual,
      stated,
      reason:
          'lower "Open rows" in $_path when a row is covered; it may not '
          'grow without a row saying why',
    );
  });
}
