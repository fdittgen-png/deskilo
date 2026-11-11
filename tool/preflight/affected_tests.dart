// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3715 -- the local gate is chosen by what CONSUMES a change, not by the files
// edited: the table (`test_map.json`) names the tests a path pattern drags in,
// and the importers of a changed lib file are found by search. Lists tests; it
// runs none and changes no CI.
import 'dart:convert';
import 'dart:io';

/// One row of the table: any of [patterns] -> [tests].
class TestMapRow {
  const TestMapRow(this.patterns, this.tests);

  final List<String> patterns;
  final List<String> tests;
}

/// The table read from [file] (`tool/preflight/test_map.json`).
List<TestMapRow> readTestMap(File file) {
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return [
    for (final row in (json['rows'] as List).cast<Map<String, dynamic>>())
      TestMapRow(
        (row['patterns'] as List).cast<String>(),
        (row['tests'] as List).cast<String>(),
      ),
  ];
}

/// [pattern] as a regular expression: `**` crosses folders, `*` stays in one.
RegExp patternRegExp(String pattern) {
  final b = StringBuffer('^');
  for (var i = 0; i < pattern.length; i++) {
    final c = pattern[i];
    if (c == '*' && i + 1 < pattern.length && pattern[i + 1] == '*') {
      b.write('.*');
      i++;
    } else if (c == '*') {
      b.write('[^/]*');
    } else {
      b.write(RegExp.escape(c));
    }
  }
  return RegExp('${b.toString()}\$');
}

/// The test files of [testSources] (path -> content) that import a changed
/// lib file, as `package:deskilo/<path>` or as a relative path ending in it.
Set<String> importersOf(
  Iterable<String> changed,
  Map<String, String> testSources,
) {
  final libs = [
    for (final p in changed)
      if (p.startsWith('lib/') && p.endsWith('.dart')) p.substring(4),
  ];
  if (libs.isEmpty) return {};
  return {
    for (final MapEntry(:key, :value) in testSources.entries)
      if (libs.any((l) => value.contains("package:deskilo/$l'"))) key,
  };
}

/// The tests to run for [changed]: the rows that match plus the importers.
List<String> affectedTests(
  Iterable<String> changed,
  List<TestMapRow> table,
  Map<String, String> testSources,
) {
  final out = <String>{};
  for (final row in table) {
    final matchers = row.patterns.map(patternRegExp).toList();
    if (changed.any((p) => matchers.any((m) => m.hasMatch(p)))) {
      out.addAll(row.tests);
    }
  }
  out
    ..addAll(importersOf(changed, testSources))
    // A changed test file runs itself.
    ..addAll(
      changed.where((p) => p.startsWith('test/') && p.endsWith('_test.dart')),
    );
  return out.toList()..sort();
}

/// Every `*_test.dart` under `test/` of [root], path -> content.
Map<String, String> readTestSources(String root) => {
  for (final f in Directory('$root/test').listSync(recursive: true))
    if (f is File && f.path.endsWith('_test.dart'))
      f.path.substring(root.length + 1): f.readAsStringSync(),
};
