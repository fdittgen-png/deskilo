// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 checkpoint 1 — the dependency map says what the tree says.
//
// A committed generated file with no regeneration check drifts silently,
// and a map of the architecture that is six months stale is worse than
// none: somebody plans against it.
//
// It also holds the map and `layering_test` to the SAME numbers. They
// read one scanner (`tool/layering/analysis.dart`) precisely so that the
// document cannot say 24 while the ratchet says 25, which is exactly how
// #1449's own baseline came to be wrong the day it was written.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/dependency_map.dart' show mapOfTree, output;

import '../../tool/layering/analysis.dart';

void main() {
  test('docs/design/APPLICATION_BOUNDARIES.md is what the tool produces '
      'today (run: dart run tool/dependency_map.dart)', () {
    final committed = File(output);
    expect(committed.existsSync(), isTrue);
    // #2121 — compared, not rewritten: the committed map must BE the
    // tool's output for this tree, byte for byte.
    expect(committed.readAsStringSync(), mapOfTree().text,
        reason: 'run `dart run tool/dependency_map.dart` and commit');
  });

  test('the map carries no volume that moves with an unrelated edit '
      '(#2121)', () {
    final text = mapOfTree().text;
    expect(text, isNot(contains('imports.**')),
        reason: 'a total moves with every pull request');
    expect(RegExp(r'^\| `[a-z_]+ -> [a-z_]+` \| \d+ \|$', multiLine: true)
        .hasMatch(text), isFalse,
        reason: 'per-pair counts move with every import');
    expect(RegExp(r'^\| `lib/[^`]+\.dart` \| \d+ \|$', multiLine: true)
        .hasMatch(text), isFalse,
        reason: 'line counts move with every edit');
  });

  test('every feature the map names in a context exists in the tree', () {
    final features = handWrittenDartFiles('lib/features').toList();
    final known = {
      for (final f in features)
        if (featureOf(f.path) != null) featureOf(f.path)!,
    };
    final text = File('docs/design/APPLICATION_BOUNDARIES.md')
        .readAsStringSync();
    final named = RegExp(r'^\| (?:Booking|Finance|Workspace configuration) \| `(\w+)` \|',
            multiLine: true)
        .allMatches(text)
        .map((m) => m.group(1)!)
        .toSet();
    expect(named, isNotEmpty);
    expect(
      named.difference(known),
      isEmpty,
      reason: 'the map puts these in a context and the tree has no such '
          'feature — a context list that outlives its features is how a '
          'map starts lying',
    );
  });

  test('the scanner the map and the ratchet share can tell a comment from '
      'code', () {
    // The failure this repository has made twice: a rule that scans raw
    // text counts the paragraph explaining it.
    const source = '''
// ref.read(moneyRepositoryProvider) is what this rule forbids.
final x = 1;
''';
    expect(repositoryUse.hasMatch(source), isTrue,
        reason: 'raw text does match — which is the trap');
    expect(repositoryUse.hasMatch(withoutComments(source)), isFalse);
  });
}
