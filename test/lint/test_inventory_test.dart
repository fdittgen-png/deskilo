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
}
