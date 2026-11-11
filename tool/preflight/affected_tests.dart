// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3715 -- the local gate is chosen by what CONSUMES a change, not by the files
// edited: the table (`test_map.json`) names the tests a path pattern drags in,
// and the importers of a changed lib file are found by search. Lists tests; it
// runs none and changes no CI.
import 'dart:convert';
import 'dart:io';

/// One row of the table: any of [patterns] -> [tests], and optionally a
/// [note]: a step no local test can stand in for, said with the list.
class TestMapRow {
  const TestMapRow(this.patterns, this.tests, {this.note});

  final List<String> patterns;
  final List<String> tests;
  final String? note;
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
        note: row['note'] as String?,
      ),
  ];
}

/// The notes of the rows [changed] matches, in the table's order.
List<String> notesFor(Iterable<String> changed, List<TestMapRow> table) => [
  for (final row in table)
    if (row.note case final note?)
      if (changed.any(
        (p) => row.patterns.any((m) => patternRegExp(m).hasMatch(p)),
      ))
        note,
];

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

/// The index of the brace that closes the one at [open] in [s], or -1.
int _closing(String s, int open) {
  var depth = 0;
  for (var k = open; k < s.length; k++) {
    if (s[k] == '{') depth++;
    if (s[k] == '}' && --depth == 0) return k;
  }
  return -1;
}

final _icuHead = RegExp(r'^\s*\w+\s*,\s*(plural|select|selectordinal)\s*,');

/// The runs of plain text of an ARB [message]: what stays when placeholders
/// and plural or select syntax go (the text of every case is kept).
List<String> _plainRuns(String message) {
  final out = <String>[];
  final run = StringBuffer();
  var i = 0;
  while (i < message.length) {
    if (message[i] != '{') {
      run.write(message[i++]);
      continue;
    }
    out.add(run.toString());
    run.clear();
    final end = _closing(message, i);
    if (end < 0) break;
    final inner = message.substring(i + 1, end);
    final head = _icuHead.firstMatch(inner);
    if (head != null) {
      for (var j = head.end; j < inner.length; j++) {
        if (inner[j] != '{') continue;
        final caseEnd = _closing(inner, j);
        if (caseEnd < 0) break;
        out.addAll(_plainRuns(inner.substring(j + 1, caseEnd)));
        j = caseEnd;
      }
    }
    i = end + 1;
  }
  return out..add(run.toString());
}

/// The pieces of [message] worth searching for: plain text of at least two
/// words and [min] characters. One word alone ("settings,") is also an
/// identifier in half the test tree, so it is not searched.
Set<String> literalPieces(String message, {int min = 6}) => {
  for (final run in _plainRuns(message).map((r) => r.trim()))
    if (run.length >= min && run.contains(' ')) run,
};

/// #3752 -- the tests that still hold a piece of an English sentence whose
/// text changed or went between [before] and [after] (two ARB maps): an
/// assertion on the old wording, wherever it lives. Only pieces the new text
/// no longer has are searched.
Set<String> testsOfChangedSentences(
  Map<String, Object?> before,
  Map<String, Object?> after,
  Map<String, String> testSources,
) {
  final gone = <String>{};
  for (final MapEntry(:key, :value) in before.entries) {
    if (key.startsWith('@') || value is! String || after[key] == value) continue;
    final now = after[key];
    gone.addAll(
      literalPieces(value).difference(
        now is String ? literalPieces(now) : const <String>{},
      ),
    );
  }
  if (gone.isEmpty) return {};
  return {
    for (final MapEntry(:key, :value) in testSources.entries)
      if (gone.any(value.contains)) key,
  };
}

/// Every `*_test.dart` under `test/` of [root], path -> content.
Map<String, String> readTestSources(String root) => {
  if (Directory('$root/test').existsSync())
    for (final f in Directory('$root/test').listSync(recursive: true))
      if (f is File && f.path.endsWith('_test.dart'))
        f.path.substring(root.length + 1): f.readAsStringSync(),
};
