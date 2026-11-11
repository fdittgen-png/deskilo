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

/// The patterns of generated files whose importers are not searched.
List<String> readNoImporterSearch(File file) =>
    ((jsonDecode(file.readAsStringSync())
                as Map<String, dynamic>)['no_importer_search']
            as List?)
        ?.cast<String>() ??
    const [];

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
  Map<String, String> testSources, {
  List<String> skip = const [],
}) {
  final skipped = skip.map(patternRegExp).toList();
  final libs = [
    for (final p in changed)
      if (p.startsWith('lib/') &&
          p.endsWith('.dart') &&
          !skipped.any((m) => m.hasMatch(p)))
        p.substring(4),
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
  Map<String, String> testSources, {
  List<String> skipImporters = const [],
}) {
  final out = <String>{};
  for (final row in table) {
    final matchers = row.patterns.map(patternRegExp).toList();
    if (changed.any((p) => matchers.any((m) => m.hasMatch(p)))) {
      out.addAll(row.tests);
    }
  }
  out
    ..addAll(importersOf(changed, testSources, skip: skipImporters))
    // A changed test file runs itself.
    ..addAll(
      changed.where((p) => p.startsWith('test/') && p.endsWith('_test.dart')),
    );
  return out.toList()..sort();
}

/// Every `*_test.dart` under `test/` of [root], path -> content.
Map<String, String> readTestSources(String root) => {
  if (Directory('$root/test').existsSync())
    for (final f in Directory('$root/test').listSync(recursive: true))
      if (f is File && f.path.endsWith('_test.dart'))
        f.path.substring(root.length + 1): f.readAsStringSync(),
};
