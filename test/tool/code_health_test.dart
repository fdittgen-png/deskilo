// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2491 — the code-health tool measures what the hand count says.
//
// Each snippet under test/tool/code_health_fixtures/ is small enough to
// count by hand, and the table below is that count (cyclomatic starts at 1;
// cognitive adds 1 plus the nesting for a branch; an `else if` adds 1 and
// no nesting of its own; a run of one boolean operator counts once). A
// drift in the tool changes a number here before it changes the baseline.
// The one unparsable snippet must make the tool FAIL: a file the parser
// rejects is never measured as if it were whole.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/code_health.dart';

String _fixture(String name) =>
    File('test/tool/code_health_fixtures/$name.fixture').readAsStringSync();

FileHealth _measure(String name) =>
    measureSource('fixtures/$name.dart', _fixture(name));

// id suffix after the path, then cyclomatic, cognitive, nesting, parameters,
// length in lines.
typedef _Row = (String, int, int, int, int, int);

void _expectRows(String name, List<_Row> rows) {
  final file = _measure(name);
  expect(file.errors, isEmpty);
  expect(
    [
      for (final f in file.functions)
        (
          f.id.substring('fixtures/$name.dart#'.length),
          f.cyclomatic,
          f.cognitive,
          f.nesting,
          f.parameters,
          f.length,
        ),
    ],
    rows,
  );
}

void main() {
  test('an if / else-if / else chain: the else-if adds 1, no nesting', () {
    // if +1, else-if +1, else +1 = 3; cyclomatic 1 + 2 branches.
    _expectRows('if_chain', [('chain(int a,int b)', 3, 3, 2, 2, 9)]);
  });

  test('nested closures nest, and an if inside one pays for it', () {
    // closure (nest 1) > if: 1 + 1 = 2; the inner closure nests to 3.
    _expectRows('closures', [('closures(List<int> xs)', 2, 2, 3, 1, 9)]);
  });

  test('a switch expression counts every case, `??` is cyclomatic only', () {
    // cyclomatic 1 + `??` + three cases; cognitive: the switch, 1.
    _expectRows('switch_coalesce', [('sw(int a,String? b)', 5, 1, 1, 2, 4)]);
  });

  test('collection-if, collection-for, ?: and mixed && / ||', () {
    // if-element 1, `||` 1, `&&` 1 (a different operator counts again),
    // for-element 1, ?: 1 = 5; cyclomatic 1 + the same six decisions
    // (each operator is a decision).
    _expectRows('collection_elements',
        [('coll(bool a,bool b,bool c)', 6, 5, 1, 3, 7)]);
  });

  test('multi-line signatures, constructor initialisers, getters', () {
    // The constructor's initialiser list is not part of its body: only the
    // `if` in the body counts.
    final rows = _measure('signatures').functions;
    expect(rows.map((f) => f.id.substring('fixtures/signatures.dart#'.length)),
        [
          'Box.new(this.a,{required this.b,int c})',
          'Box.describe(int first,String second,[bool third])',
          'Box.get twice()',
        ]);
    expect([for (final f in rows) f.parameters], [3, 3, 0]);
    expect([for (final f in rows) f.cyclomatic], [2, 2, 1]);
    expect([for (final f in rows) f.cognitive], [1, 1, 0]);
    expect([for (final f in rows) f.nesting], [1, 1, 0]);
    expect([for (final f in rows) f.length], [9, 6, 1]);
  });

  test('loops, catch, do-while and switch statements', () {
    // for 1, while 1+1, catch 1+2, do 1, switch 1 = 8; cyclomatic: the
    // four loops and the catch, plus the two cases (default is free).
    _expectRows('statements', [
      ('loops(List<int> xs)', 7, 8, 3, 1, 22),
      ('run()', 1, 0, 0, 0, 1),
    ]);
  });

  test('a `part of` file is flagged and its functions are measured', () {
    final file = _measure('part_file');
    expect(file.isPart, isTrue);
    expect(file.loc, 4);
    expect(file.functions.single.cyclomatic, 2);
    expect(file.functions.single.cognitive, 1);
  });

  test('an unparsable file reports its errors instead of being measured', () {
    final file = _measure('unparsable');
    expect(file.errors, isNotEmpty);
    expect(file.errors.first, startsWith('fixtures/unparsable.dart:'));
  });

  test('the command line exits 1 on an unparsable file and names it', () {
    final dir = Directory.systemTemp.createTempSync('code-health-parse');
    try {
      File('${dir.path}/ok.dart').writeAsStringSync(_fixture('if_chain'));
      File('${dir.path}/bad.dart').writeAsStringSync(_fixture('unparsable'));
      final r = Process.runSync(
          'dart', ['run', 'tool/code_health.dart', dir.path]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect(r.stderr, contains('bad.dart'));
      expect(r.stderr, contains('PARSE ERROR'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('the same tree gives byte-identical JSON, whatever the walk order', () {
    final dir = Directory.systemTemp.createTempSync('code-health-det');
    try {
      for (final n in ['if_chain', 'closures', 'statements', 'part_file']) {
        File('${dir.path}/$n.dart').writeAsStringSync(_fixture(n));
      }
      final a = measurementJson(measureTree(dir.path));
      final b = measurementJson(measureTree(dir.path));
      expect(a, b);
      expect(a, contains('closures(List<int> xs)'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('the cycles mode lists the pairs APPLICATION_BOUNDARIES.md lists', () {
    final doc = File('docs/design/APPLICATION_BOUNDARIES.md')
        .readAsStringSync()
        .split('Reciprocal:')
        .last
        .split('## ')
        .first;
    final documented = RegExp(r'`([a-z_]+ <-> [a-z_]+)`')
        .allMatches(doc)
        .map((m) => m.group(1)!)
        .toList()
      ..sort();
    final listed = cycles().map((l) => l.split('  ').first).toList();
    expect(listed, documented);
  });
}
