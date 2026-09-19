// SPDX-License-Identifier: 0BSD
//
// #1381 — the Demo coverage map names files that exist.
//
// A map from "what protects Demo" to the file that does it is read as
// reassurance. One that outlives its tests is therefore worse than no
// map at all, so this reads `docs/testing/DEMO_COVERAGE.md` back and
// checks every path in it.
//
// It also checks the other direction, loosely: a Demo test file that the
// map does not mention is a row somebody forgot to write down.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String mapPath = 'docs/testing/DEMO_COVERAGE.md';

/// The `test/…` paths the map's table names.
Set<String> mappedFiles(String markdown) => {
      for (final m in RegExp(r'`(test/[^`]+\.dart)`').allMatches(markdown))
        m.group(1)!,
    };

void main() {
  final markdown = File(mapPath).readAsStringSync();

  test('every file the coverage map names exists', () {
    final named = mappedFiles(markdown);
    expect(named, isNotEmpty);
    final missing = named.where((p) => !File(p).existsSync()).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'the map names tests that are gone. Delete the row, or '
          'restore the test — a coverage map is read as reassurance, and '
          'a stale one gives it falsely:\n${missing.join('\n')}',
    );
  });

  test('every Demo test is on the map', () {
    final onDisk = [
      ...Directory('test/core/demo')
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.endsWith('_test.dart')),
      'test/ux/demo_journeys_test.dart',
      'test/lint/no_render_tree_blur_test.dart',
    ]..sort();
    final named = mappedFiles(markdown);
    final unlisted = onDisk.where((p) => !named.contains(p)).toList();
    expect(
      unlisted,
      isEmpty,
      reason: 'these protect Demo and the map does not say so — add the '
          'row, in the words of what it protects rather than the name of '
          'the file:\n${unlisted.join('\n')}',
    );
  });

  test('the map says what the suite does NOT do', () {
    // #1381 asks for a small suite, which is a claim about what was left
    // out as much as what went in. A map that only lists what exists
    // invites the next person to add the rest.
    expect(markdown, contains('deliberately does not do'));
    expect(
      markdown,
      contains('Screenshots'),
      reason: 'the issue asks that screenshots come from the canonical '
          'dataset; they do not yet, and the map has to say so rather '
          'than leave the row looking met',
    );
  });
}
