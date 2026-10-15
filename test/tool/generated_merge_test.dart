// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2121 — two pull requests that each regenerate a committed aggregate
// merge without a conflict, and the merged text is exactly what the
// generator writes for both contributions together.
//
// git reports a conflict when two sides change the same OR ADJACENT lines.
// An aggregate in contribution order (every new ARB key appended at the
// end of its fragment), with a total line, or with entries on adjacent
// lines therefore conflicts on almost every pair of open pull requests,
// and each conflict costs a merge of master, a regeneration and a fresh
// CI run. Each case below merges two fixture contributions with
// `git merge-file` and checks the result against the generator; each
// also runs the OLD layout through the same merge as a negative control,
// so the test proves it can tell a layout that conflicts from one that
// does not.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_arb.dart' show encodeArb;
import '../../tool/code_health_budgets.dart' show Budgets;
import '../../tool/dependency_map.dart' show render;

/// A three-way merge as git does it: null when it conflicts.
String? _merge(String base, String ours, String theirs) {
  final dir = Directory.systemTemp.createTempSync('generated_merge');
  try {
    File('${dir.path}/base').writeAsStringSync(base);
    File('${dir.path}/ours').writeAsStringSync(ours);
    File('${dir.path}/theirs').writeAsStringSync(theirs);
    final r = Process.runSync('git', [
      'merge-file',
      '-p',
      '${dir.path}/ours',
      '${dir.path}/base',
      '${dir.path}/theirs',
    ]);
    if (r.exitCode < 0) fail('git merge-file failed: ${r.stderr}');
    return r.exitCode == 0 ? r.stdout as String : null;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

Map<String, dynamic> _strings(List<String> keys) => {
      '@@locale': 'en',
      for (final k in keys) ...{
        k: 'Text of $k',
        '@$k': {'description': 'What $k says.'},
      },
    };

void main() {
  test('ARB aggregate: two pull requests adding strings to the same '
      'feature merge cleanly into the generator output', () {
    // The feature's fragment holds B and D; another fragment holds Z.
    // Pull request 1 appends C to the feature, pull request 2 appends E.
    final base = ['recorderB', 'recorderD', 'zone'];
    final one = ['recorderB', 'recorderD', 'recorderC', 'zone'];
    final two = ['recorderB', 'recorderD', 'recorderE', 'zone'];
    final both = ['recorderB', 'recorderD', 'recorderC', 'recorderE', 'zone'];

    final merged = _merge(encodeArb(_strings(base)), encodeArb(_strings(one)),
        encodeArb(_strings(two)));
    expect(merged, isNotNull, reason: 'the sorted aggregate conflicted');
    expect(merged, encodeArb(_strings(both)));
    expect(encodeArb(_strings(both)), encodeArb(_strings(both.reversed.toList())),
        reason: 'the output must not depend on contribution order');

    // Negative control: the fragment-order layout this replaced.
    String old(List<String> keys) =>
        '${const JsonEncoder.withIndent('  ').convert(_strings(keys))}\n';
    expect(_merge(old(base), old(one), old(two)), isNull,
        reason: 'the control must conflict, or this test proves nothing');
  });

  test('dependency map: two pull requests adding different relationships '
      'merge cleanly into the generator output', () {
    final reads = {'money': ['lib/features/money/presentation/a.dart']};
    const large = ['lib/app/router.dart'];
    final base = ['money -> plan', 'plan -> workspace'];
    final one = [...base, 'money -> profile'];
    final two = [...base, 'plan -> zones'];
    final both = [...base, 'money -> profile', 'plan -> zones'];

    final merged = _merge(render(reads, base, large), render(reads, one, large),
        render(reads, two, large));
    expect(merged, isNotNull, reason: 'the map conflicted');
    expect(merged, render(reads, both, large));

    // Negative control: the totals line the old map carried, which both
    // sides rewrite (pull request 1 brings four imports, 2 brings two).
    String old(List<String> pairs, int imports) =>
        '${render(reads, pairs, large)}**${pairs.length} directed '
        'relationships, $imports imports.**\n';
    expect(_merge(old(base, 10), old(one, 14), old(two, 12)), isNull);
  });

  test('file-length budgets: lowering two neighbouring files merges cleanly '
      'in the generated block (#2598)', () {
    String budgets(int a, int b) => Budgets(partOfFiles: 1, maps: {
          'fileLength': {'lib/a.dart': a, 'lib/b.dart': b},
          'setState': {},
          'repositoryInWidgets': {},
          'pairBudget': {},
        }).render();
    final merged = _merge(budgets(700, 800), budgets(690, 800), budgets(700, 780));
    expect(merged, budgets(690, 780));

    // Negative control: the same entries on adjacent lines conflict.
    String adjacent(int a, int b) =>
        '"fileLength": {\n  "lib/a.dart": $a,\n  "lib/b.dart": $b\n}\n';
    expect(_merge(adjacent(700, 800), adjacent(690, 800), adjacent(700, 780)),
        isNull);
    // And two lowerings of the SAME file still conflict, which is right:
    // the combined count needs a new number.
    expect(_merge(budgets(700, 800), budgets(690, 800), budgets(680, 800)),
        isNull);
  });
}
