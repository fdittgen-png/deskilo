// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477/#2484 -- the shared counting kit of the "no hardcoded values"
// ratchets (`tax_literals_test.dart`, `business_literals_test.dart`): count
// the thing so a partial win is visible, never a presence list. A ratchet
// names its files, counts matches of its patterns in code lines (comments
// skipped), and fails when the count differs from its recorded ceiling --
// up is a defect, down must be recorded.
import 'dart:io';

/// A named class of literal: what it matches and why it is a business value.
class LiteralKind {
  const LiteralKind(this.name, this.pattern);

  final String name;
  final RegExp pattern;
}

/// The files of [roots] ending in [suffix] (directories are walked).
List<File> filesUnder(Iterable<String> roots, {String suffix = '.dart'}) {
  final out = <File>[];
  for (final root in roots) {
    final entity = FileSystemEntity.typeSync(root);
    if (entity == FileSystemEntityType.file) {
      out.add(File(root));
    } else if (entity == FileSystemEntityType.directory) {
      out.addAll(Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith(suffix)));
    }
  }
  return out..sort((a, b) => a.path.compareTo(b.path));
}

/// Code lines of [file]: line comments and blank lines removed.
List<String> codeLines(File file, {String comment = '//'}) => [
      for (final line in file.readAsLinesSync())
        if (line.trim().isNotEmpty && !line.trimLeft().startsWith(comment)) line,
    ];

/// The text an anchored patch QUOTES in order to remove it: the `$old$ ... $old$`
/// blocks of a migration (#2479). A literal there is the thing being deleted,
/// not one being added, so it is not counted; the `$new$` side is.
final RegExp anchoredOldText = RegExp(r'\$old\$.*?\$old\$', dotAll: true);

/// Matches of each kind per file (only files with at least one). [skip] cuts
/// text out of a file before counting.
Map<String, Map<String, int>> countLiterals(
  Iterable<File> files,
  Iterable<LiteralKind> kinds, {
  String comment = '//',
  RegExp? skip,
}) {
  final byKind = {for (final k in kinds) k.name: <String, int>{}};
  for (final file in files) {
    var text = codeLines(file, comment: comment).join('\n');
    if (skip != null) text = text.replaceAll(skip, '');
    for (final k in kinds) {
      final n = k.pattern.allMatches(text).length;
      if (n > 0) byKind[k.name]![file.path] = n;
    }
  }
  return byKind;
}

int total(Map<String, int> perFile) => perFile.values.fold(0, (a, b) => a + b);

/// What a failed ratchet says: the rule, the kind, both numbers, the
/// heaviest files and the way out.
String ratchetMessage({
  required String rule,
  required String kind,
  required int ceiling,
  required int actual,
  required Map<String, int> perFile,
}) {
  final top = (perFile.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(5)
      .map((e) => '  ${e.value}  ${e.key}')
      .join('\n');
  final verb = actual > ceiling
      ? 'went UP: a business value is configuration or reference data with a '
          'UI point, not a literal (docs/AGENT_RULES.md, "No hardcoded values")'
      : 'went DOWN: record the win by lowering the ceiling to $actual';
  return '$rule: "$kind" $verb.\n  ceiling $ceiling, now $actual.\n$top';
}
