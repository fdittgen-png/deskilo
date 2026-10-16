// SPDX-License-Identifier: AGPL-3.0-or-later
//
// File-length budget with a ratcheting allow-list.
//
// Nobody plans a 1 500-line screen; it accretes fifty lines per feature
// until nobody can hold it. The budget makes growth VISIBLE: a file over
// it must either shed weight (extract widgets, split by concern — the
// shared-building-blocks pattern in Architecture.md exists for exactly
// this) or have its baseline raised here, in a reviewable diff, with the
// reason in the PR description. Silent accretion is the only forbidden
// path.
//
// #2598 — the budgets are generated: `budgets.fileLength` in
// docs/design/CODE_HEALTH_BASELINE.json, written by
// `dart run tool/code_health.dart --baseline`, which keeps the lower of the
// held number and the file's length plus 20 lines, and refuses a raise. A
// file over 500 lines that is not listed there fails; the reason a file is
// exempt is one line in docs/design/CODE_HEALTH_BUDGET_REASONS.txt.
//
// Baseline numbers may go DOWN freely — please lower one whenever you
// shrink a file, or the coupling quietly grows back to the stale cap.
// Known hazard from the sibling project: when two branches touch the
// same baseline entry, the resolved number must be the COMBINED
// post-merge line count, not either branch's figure.
//
// #2121 — layout rule: no two entries on adjacent lines. git reports a
// conflict for changes to ADJACENT lines, so two pull requests raising
// two neighbouring files' budgets used to collide although they had
// nothing in common. A blank line (or a comment) between entries lets
// them merge cleanly; two pull requests raising the SAME file still
// collide, which is right — the combined count needs a new number.
// The last test below holds the layout.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/code_health_budgets.dart';

void main() {
  test('no lib/ file outgrows its budget unnoticed', () {
    final failures = budgetFailures(Budgets.load(), measureBudgetActuals(),
        only: 'fileLength');
    expect(failures, isEmpty,
        reason: '${failures.join('\n')}\n\n'
            'Extract widgets or split by concern first (see the shared '
            'building blocks in Architecture.md). A budget is never '
            'raised; a file that has to exceed $defaultFileLength lines '
            'takes `--allow-new=fileLength:<path>` once and a line in '
            '$reasonsPath.');
  });

  test('every reason names a budget that exists (#2598)', () {
    final held = Budgets.load();
    final reasons = parseReasons(File(reasonsPath).readAsStringSync());
    final orphan = [
      for (final k in reasons.keys)
        if (!held.maps[k.split(' ').first]!.containsKey(k.substring(k.indexOf(' ') + 1)))
          k,
    ];
    expect(orphan, isEmpty,
        reason: 'delete these lines of $reasonsPath: ${orphan.join(', ')}');
  });

  test('no two budget entries sit on adjacent lines (#2121)', () {
    final lines = File('docs/design/CODE_HEALTH_BASELINE.json')
        .readAsLinesSync();
    final start = lines.indexWhere((l) => l.startsWith('  "budgets": {'));
    final end = lines.indexWhere((l) => l.startsWith('  },'), start);
    final entry = RegExp(r'^\s+"[^"]+": \d+,?$');
    final adjacent = <String>[
      for (var i = start + 1; i < end - 1; i++)
        if (entry.hasMatch(lines[i]) && entry.hasMatch(lines[i + 1]))
          'lines ${i + 1}-${i + 2}',
    ];
    expect(adjacent, isEmpty,
        reason: 'budget entries need a blank line between them: adjacent '
            'lines conflict whenever two pull requests lower neighbours — '
            'run `$budgetCommand`');
    expect(start, greaterThan(0));
  });
}
