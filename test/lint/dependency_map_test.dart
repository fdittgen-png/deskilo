// SPDX-License-Identifier: 0BSD
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

import '../../tool/layering/analysis.dart';

void main() {
  test('docs/design/APPLICATION_BOUNDARIES.md is what the tool produces '
      'today (run: dart run tool/dependency_map.dart)', () {
    final committed = File('docs/design/APPLICATION_BOUNDARIES.md');
    expect(committed.existsSync(), isTrue);

    final result = Process.runSync(
      'dart',
      ['run', 'tool/dependency_map.dart'],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');

    // The tool rewrites the file in place, so a drift shows up as a
    // dirty tree; comparing the content it just wrote to what git has
    // would need git. Instead: the file now matches the tree by
    // construction, and the numbers below are the ones a reader acts on.
    final text = committed.readAsStringSync();
    expect(text, startsWith('<!-- GENERATED'));

    final features = handWrittenDartFiles('lib/features').toList();
    final reads = repositoryReadsByFeature(features);
    final total = reads.values.fold<int>(0, (n, l) => n + l.length);
    expect(
      text,
      contains('**$total files** across ${reads.length} features.'),
      reason: 'the headline count in the map is the count in the tree',
    );

    final pairs = crossFeatureImports(features);
    final volume = pairs.values.fold<int>(0, (n, v) => n + v);
    expect(
      text,
      contains('**${pairs.length} directed relationships, $volume imports.**'),
    );
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
