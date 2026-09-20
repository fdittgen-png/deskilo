// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — what the layering rules measure, in one place.
//
// `layering_test` has counted these things since #1233: which
// presentation files still resolve a repository, and how many imports
// stand behind each cross-feature pair. #1449 asks for the same numbers
// as a document, because its own baseline was a snapshot that master had
// already moved past.
//
// Two scanners would be two answers. These functions are the one, so the
// document and the ratchet cannot disagree: the lint reads them, and so
// does `tool/dependency_map.dart`.
import 'dart:io';

/// A widget reaching a repository: `ref.read(xRepositoryProvider)` or
/// `ref.watch(…)`, the exact shape #1234 counted 125 of.
final RegExp repositoryUse =
    RegExp(r'ref\.(read|watch)\(\s*[a-zA-Z]+RepositoryProvider');

final RegExp importRe = RegExp("import '([^']+)'");

/// Source with `//` comments removed.
///
/// A scanner that reads raw text reports the comment EXPLAINING a rule as
/// a violation of it, which this repository has learned twice.
String withoutComments(String source) => source
    .split('\n')
    .map((line) {
      final at = line.indexOf('//');
      return at < 0 ? line : line.substring(0, at);
    })
    .join('\n');

/// The feature a repo-relative path belongs to, or null.
String? featureOf(String path) {
  final parts = path.split('/');
  if (parts.length > 2 && parts[0] == 'lib' && parts[1] == 'features') {
    return parts[2];
  }
  return null;
}

/// Resolves [import] against [fromDir] to a repo-relative path, or null
/// for package and dart imports.
String? resolveRelative(String fromDir, String import) {
  if (!import.startsWith('.')) return null;
  final parts = <String>[...fromDir.split('/')];
  for (final seg in import.split('/')) {
    if (seg == '.' || seg.isEmpty) continue;
    if (seg == '..') {
      parts.removeLast();
    } else {
      parts.add(seg);
    }
  }
  return parts.join('/');
}

/// The presentation files of each feature that still resolve a
/// repository, by feature, paths sorted.
Map<String, List<String>> repositoryReadsByFeature(Iterable<File> files) {
  final found = <String, List<String>>{};
  for (final file in files) {
    if (!file.path.contains('/presentation/')) continue;
    final feature = featureOf(file.path);
    if (feature == null) continue;
    if (!repositoryUse.hasMatch(withoutComments(file.readAsStringSync()))) {
      continue;
    }
    (found[feature] ??= []).add(file.path);
  }
  for (final list in found.values) {
    list.sort();
  }
  return found;
}

/// How many imports stand behind each `source -> target` feature pair.
Map<String, int> crossFeatureImports(Iterable<File> files) {
  final counts = <String, int>{};
  for (final file in files) {
    final src = featureOf(file.path);
    if (src == null) continue;
    for (final m in importRe.allMatches(file.readAsStringSync())) {
      final imp = m.group(1)!;
      String? target;
      if (imp.startsWith('package:deskilo/features/')) {
        target = imp.split('/')[2];
      } else {
        final resolved = resolveRelative(
          file.path.substring(0, file.path.lastIndexOf('/')),
          imp,
        );
        if (resolved != null) target = featureOf(resolved);
      }
      if (target != null && target != src) {
        counts.update('$src -> $target', (n) => n + 1, ifAbsent: () => 1);
      }
    }
  }
  return counts;
}

/// Pairs that point both ways, as `a <-> b`, each listed once.
Set<String> reciprocalPairs(Map<String, int> counts) {
  final out = <String>{};
  for (final pair in counts.keys) {
    final parts = pair.split(' -> ');
    final back = '${parts[1]} -> ${parts[0]}';
    if (counts.containsKey(back)) {
      final ends = [parts[0], parts[1]]..sort();
      out.add('${ends[0]} <-> ${ends[1]}');
    }
  }
  return out;
}

/// True for files produced by codegen — never hand-edited, never
/// counted. The same three rules `test/lint/lint_sources.dart` applies,
/// stated here so a tool outside `test/` can share them.
bool isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.contains('lib/l10n/');

/// Hand-written Dart files under [root].
Iterable<File> handWrittenDartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !isGenerated(f.path));
