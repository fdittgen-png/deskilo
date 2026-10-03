// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1334 — the test inventory lists exactly the tests that exist.
//
// docs/testing/TEST_INVENTORY.md classifies every test file. A file added
// or removed without regenerating it would leave a test nobody triaged,
// or a row describing a test that is gone. The file SET is what is
// pinned, not every cell: rewording a header should not fail a build.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/test_inventory/inventory.dart';

Set<String> _rowsIn(String markdown) => {
      for (final m in RegExp(r'^\| `([^`]+)` \|', multiLine: true)
          .allMatches(markdown))
        m.group(1)!,
    };

void main() {
  test('the header paragraph is the stated invariant', () {
    expect(
      statedInvariant(
        '// SPDX-License-Identifier: AGPL-3.0-or-later\n//\n// #1 — the rule.\n// Two lines.\n//\n// Detail.\nimport "x";',
        sql: false,
      ),
      '#1 — the rule. Two lines.',
    );
    expect(statedInvariant('import "x";', sql: false), isEmpty);
    expect(
      statedInvariant('-- SPDX-License-Identifier: AGPL-3.0-or-later\n--\n-- 0216 — policies.\nbegin;',
          sql: true),
      '0216 — policies.',
    );
  });

  test('every test file is in the inventory, and nothing else is', () {
    final file = File(inventoryPath);
    expect(file.existsSync(), isTrue,
        reason: 'run `dart run tool/test_inventory.dart`');
    final listed = _rowsIn(file.readAsStringSync());
    final actual = {for (final e in classify()) e.path};

    expect(actual.difference(listed), isEmpty,
        reason: 'new test files are not classified — run '
            '`dart run tool/test_inventory.dart` and commit the inventory');
    expect(listed.difference(actual), isEmpty,
        reason: 'the inventory lists test files that no longer exist — run '
            '`dart run tool/test_inventory.dart` and commit the inventory');
  });

  test('every action is one the triage allows', () {
    for (final e in classify()) {
      expect(actions, contains(e.action), reason: e.path);
    }
  });

  // #1334 — the ratchet reached zero, so it is an invariant now.
  //
  // A ratchet at zero that only compares is a gate nothing can trip. The
  // two files that still needed it were a test whose header paragraph
  // had drifted below the imports, and one that waited a fixed 50 ms
  // for a codec instead of polling the result. Both are cheap to
  // fix and impossible to notice later, which is exactly the class of
  // thing a gate should catch on the way in.
  test('no test file needs refactoring: every one states its invariant '
      'and is deterministic', () {
    final needing = [
      for (final e in classify())
        if (e.action == 'KEEP+REFACTOR') '${e.path}: ${e.invariant}',
    ]..sort();
    expect(
      needing,
      isEmpty,
      reason: 'a file is KEEP+REFACTOR when it states no invariant in its '
          'header paragraph, uses an unseeded random source, or waits a '
          'real non-zero delay instead of polling with untilReal. State '
          'the invariant; poll the result:\n${needing.join('\n')}',
    );
  });

  // #1864 — the inventory knows every runner, says who runs what, and
  // claims no review it did not get.
  test('every registered runner family has files and a live owner', () {
    expect(deadRunnerEntries(), isEmpty);
  });

  test('no test-shaped file sits outside a registered runner family', () {
    expect(unregisteredTestFiles(), isEmpty,
        reason: 'register the runner in runnerFamilies '
            '(tool/test_inventory/inventory.dart) with who executes it');
  });

  test('reviewed dispositions name real files and survivors', () {
    final files = {for (final e in classify()) e.path};
    expect(dispositionProblems(reviewedDispositions, files), isEmpty);
  });

  test('the recovery proof is conditional integration, run by its script',
      () {
    final row = classify()
        .singleWhere((e) => e.path == 'test/core/instance/local_recovery_test.dart');
    expect(row.layer, 'integration');
    expect(row.execution, contains('DESKILO_RECOVERY_FIXTURE'));
    expect(row.execution, contains('scripts/recovery/application.py'));
    expect(row.action, 'KEEP');
  });

  test('a fixture tree: runners, conditions, names and decisions', () {
    final root = Directory.systemTemp.createTempSync('inventory_');
    addTearDown(() => root.deleteSync(recursive: true));
    void write(String path, String text) =>
        (File('${root.path}/$path')..createSync(recursive: true))
            .writeAsStringSync(text);
    const header = '// SPDX-License-Identifier: AGPL-3.0-or-later\n//\n';
    write('.github/workflows/quality.yml',
        'run: flutter test --coverage\nrun: supabase test db\n'
        'working-directory: packages/deskilo_push\n');
    write('.github/workflows/edge-functions.yml', 'deno test -A\n');
    // perf-bench.yml is missing: its family is a dead entry.
    write('scripts/run_fixture.sh', 'export DESKILO_OWNED_FIXTURE=1\n');
    write('test/a_test.dart',
        "$header// A states a.\nvoid main() { test('shows the empty state', () {}); "
        "for (final x in [1, 2]) { test('case \$x', () {}); } }\n");
    write('test/b_test.dart',
        "$header// B states b.\nvoid main() { test('shows the empty state', () {}); }\n");
    write('test/owned_test.dart',
        "$header// Owned fixture.\nfinal f = Platform.environment['DESKILO_OWNED_FIXTURE'];\n"
        "void main() { test('x', () {}, skip: f == null); }\n");
    write('test/orphan_test.dart',
        "$header// Orphan fixture.\nfinal f = Platform.environment['DESKILO_NOBODY'];\n"
        "void main() { test('y', () {}, skip: f == null); }\n");
    write('supabase/tests/database/1_x.sql', '-- X.\nselect plan(3);\n');
    write('packages/deskilo_push/test/p_test.dart', "$header// P.\nvoid main() {}\n");
    write('supabase/functions/f/index_test.ts', "// F.\nDeno.test('a', () {});\n");
    write('tool/bench/b_test.dart', "$header// Bench.\nvoid main() {}\n");
    write('integration_test/i_test.dart', "$header// I.\nvoid main() {}\n");
    write('tool/store_assets/s_test.dart', "$header// S.\nvoid main() {}\n");
    write('elsewhere/stray_test.dart', '// nobody runs me\n');

    final rows = {for (final e in classify(root: root.path)) e.path: e};
    expect(rows.values.map((e) => e.action).toSet(), {'UNREVIEWED'},
        reason: 'no rule may claim a review');
    expect(rows['test/owned_test.dart']!.layer, 'integration');
    expect(rows['test/owned_test.dart']!.execution,
        contains('set by scripts/run_fixture.sh'));
    expect(rows['test/orphan_test.dart']!.execution,
        contains('no automated owner sets it'));
    expect(rows['supabase/tests/database/1_x.sql']!.tests, 3);
    expect(rows['supabase/functions/f/index_test.ts']!.layer, 'edge');
    expect(rows['test/a_test.dart']!.tests, 2,
        reason: 'declarations, not the cases the loop expands to');
    expect(rows['test/a_test.dart']!.duplicate, contains('test/b_test.dart'),
        reason: 'a shared generic name is a candidate');
    expect(unregisteredTestFiles(root: root.path), ['elsewhere/stray_test.dart']);
    expect(deadRunnerEntries(root: root.path),
        ['benchmarks: perf-bench.yml does not exist']);

    final files = rows.keys.toSet();
    expect(
      dispositionProblems({
        'test/a_test.dart': (action: 'DELETE', reason: 'r', survivor: 'test/gone_test.dart'),
        'test/b_test.dart': (action: 'REPLACE', reason: 'r', survivor: 'test/owned_test.dart'),
        'test/owned_test.dart': (action: 'REPLACE', reason: 'r', survivor: 'test/b_test.dart'),
        'test/orphan_test.dart': (action: 'DELETE', reason: 'r', survivor: null),
        'test/missing_test.dart': (action: 'KEEP', reason: 'r', survivor: null),
      }, files),
      unorderedEquals([
        'test/a_test.dart: survivor test/gone_test.dart does not exist',
        'test/b_test.dart: replacement cycle through test/b_test.dart',
        'test/owned_test.dart: replacement cycle through test/owned_test.dart',
        'test/orphan_test.dart: DELETE names no survivor',
        'test/missing_test.dart: no such test file',
      ]),
    );
  });
}
