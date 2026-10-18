// SPDX-License-Identifier: AGPL-3.0-or-later
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

/// The `.sql` files directly under [root] (migrations, database tests),
/// sorted by path so a lint reads them in numbered order. [recursive]
/// descends. One definition of "the SQL of this repository" (#2604).
List<File> sqlFiles(String root, {bool recursive = false}) =>
    _filesWithExtension(root, '.sql', recursive: recursive);

/// The `.md` files under [root] (guides, decisions, docs), sorted.
List<File> markdownFiles(String root, {bool recursive = true}) =>
    _filesWithExtension(root, '.md', recursive: recursive);

/// The files ending in [extension] under [root], sorted by path — the walk
/// behind [sqlFiles] and [markdownFiles], for the other kinds a lint reads
/// (workflows, JSON, ARB) with no generated-file exclusion (#2604).
List<File> filesWithExtension(String root, String extension,
        {bool recursive = false}) =>
    _filesWithExtension(root, extension, recursive: recursive);

List<File> _filesWithExtension(String root, String extension,
        {required bool recursive}) =>
    Directory(root)
        .listSync(recursive: recursive)
        .whereType<File>()
        .where((f) => f.path.endsWith(extension))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// The names of the directories directly under [root], sorted (#2604).
List<String> directoryNames(String root) => [
      for (final d in Directory(root).listSync().whereType<Directory>())
        d.uri.pathSegments.where((s) => s.isNotEmpty).last,
    ]..sort();

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

/// #2386 — true for a `part of` file: its text belongs to its library,
/// which [readLibrary] reads whole.
bool isPartFile(File file) =>
    RegExp(r'^part of ', multiLine: true).hasMatch(headOf(file, bytes: 4096));

/// [file]'s text with the text of every part it names appended (#2386): a
/// screen split across part files is still one screen to a lint.
String readLibrary(File file) {
  final text = file.readAsStringSync();
  final parts = RegExp(r"^part '([^']+)';", multiLine: true).allMatches(text);
  return [
    text,
    for (final m in parts) File('${file.parent.path}/${m.group(1)}').readAsStringSync(),
  ].join('\n');
}
