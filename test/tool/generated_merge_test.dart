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
import '../../tool/code_health.dart' show baselineDocument;
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

  test('code-health baseline: two pull requests changing, adding and '
      'removing neighbouring functions merge cleanly into the generator '
      'output', () {
    Map<String, Object?> fn(String id, int cog) =>
        {'id': id, 'cog': cog, 'cyc': 1, 'len': 10, 'params': 1};
    String doc(Map<String, int> held) => baselineDocument(
        Budgets(partOfFiles: 1, maps: {'fileLength': {'lib/a.dart': 600}}),
        [for (final e in held.entries) fn(e.key, e.value)]);
    String id(String n) => 'lib/$n.dart#$n()';
    final base = {for (final n in ['a', 'b', 'd', 'f', 'h', 'j']) id(n): 40};
    // Pull request 1 lowers a and adds c; pull request 2 lowers b (a's
    // neighbour, c's too), removes f and adds i.
    final one = {...base, id('a'): 35, id('c'): 31};
    final two = {...base, id('b'): 33, id('i'): 32}..remove(id('f'));
    final both = {...one, id('b'): 33, id('i'): 32}..remove(id('f'));

    final merged = _merge(doc(base), doc(one), doc(two));
    expect(merged, isNotNull, reason: 'the baseline conflicted');
    expect(merged, doc(both));

    // Negative control: the old layout — a commit, a date and totals in
    // the header, every function on adjacent lines.
    String old(Map<String, int> held, String sha) => '{\n'
        '  "recordedSha": "$sha",\n  "recordedDate": "2026-10-2${sha.length}",\n'
        '  "totals": {"functions":${held.length}},\n  "functions": [\n'
        '${held.entries.map((e) => '    ${jsonEncode(fn(e.key, e.value))}').join(',\n')}'
        '\n  ]\n}\n';
    expect(_merge(old(base, 'a'), old(one, 'bb'), old(two, 'ccc')), isNull,
        reason: 'the control must conflict, or this test proves nothing');
    // Without the header, adjacent entries still conflict.
    String adjacent(Map<String, int> held) => old(held, 'x')
        .replaceFirst(RegExp(r'  "recordedSha".*\n.*\n.*\n'), '');
    expect(_merge(adjacent(base), adjacent(one), adjacent(two)), isNull);
    // What still conflicts, by nature of a line merge: two structural
    // changes to neighbouring entries (removing two neighbours, or adding
    // an entry next to one the other side removes) — the combined list
    // needs a look, as two lowerings of the same function do.
    final gone = {...base}..remove(id('d'));
    expect(_merge(doc(base), doc(gone), doc({...base}..remove(id('f')))),
        isNull);
  });
}
