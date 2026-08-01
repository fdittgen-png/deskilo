// SPDX-License-Identifier: 0BSD
//
// The ONE definition of "hand-written source" for the lint suite.
//
// Eight lint tests each hand-rolled the same directory walk, and the
// copies had already diverged: two forgot to exclude generated
// `.g.dart`/`.freezed.dart` files, two others forgot `lib/l10n/` — so the
// suite disagreed with itself about what counts as source. The next
// generated suffix (a build_runner mock, a `.gr.dart`) would have needed
// eight edits and gotten fewer.
//
// Per-rule policy stays per-test: exempt lists, baselines and patterns
// belong next to the rule they serve. Only the mechanics live here.

import 'dart:io';

/// True for files produced by codegen — never hand-edited, never linted.
bool isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.contains('lib/l10n/');

/// Every hand-written `.dart` file under [root] ([roots] for several).
Iterable<File> handWrittenDartFiles(String root) =>
    Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !isGenerated(f.path));

Iterable<File> handWrittenDartFilesIn(List<String> roots) =>
    roots.expand(handWrittenDartFiles);

/// Scans [files] line by line and reports `path:line: content` for every
/// line where [matches] is true. Comment lines are skipped by default —
/// a comment explaining a rule is not a violation of it.
List<String> scanLines(
  Iterable<File> files,
  bool Function(String line) matches, {
  bool skipComments = true,
}) {
  final violations = <String>[];
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (skipComments && line.startsWith('//')) continue;
      if (matches(line)) {
        // Print the line itself: a lint failure whose message does not
        // show the match costs more time than the rule saves.
        violations.add('${file.path}:${i + 1}: $line');
      }
    }
  }
  return violations;
}

/// The first [bytes] of [file] as text — for header checks. Reading the
/// whole file to inspect its first lines swept megabytes per lint run
/// while claiming to "read the first lines".
String headOf(File file, {int bytes = 512}) {
  final raf = file.openSync();
  try {
    return String.fromCharCodes(raf.readSync(bytes));
  } finally {
    raf.closeSync();
  }
}

/// Line count of [file] without materialising every line as a String —
/// a newline-byte scan, with the no-trailing-newline fixup that keeps it
/// equal to `readAsLinesSync().length`.
int lineCountOf(File file) {
  final bytes = file.readAsBytesSync();
  if (bytes.isEmpty) return 0;
  var count = 0;
  for (final b in bytes) {
    if (b == 0x0A) count++;
  }
  if (bytes.last != 0x0A) count++;
  return count;
}
