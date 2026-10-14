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
///
/// #1449 A2 — insensitive to formatting: `ref\n    .read(\n  x…` is the
/// same access as the one-line form, and the formatter produces both.
final RegExp repositoryUse = RegExp(
    r'\bref\s*\.\s*(read|watch)\s*\(\s*[a-zA-Z]+RepositoryProvider\b');

final RegExp importRe = RegExp("import '([^']+)'");

/// Source with comments and string literals removed.
///
/// A scanner that reads raw text reports the comment EXPLAINING a rule as
/// a violation of it, which this repository has learned twice; a string
/// that quotes an example is the same trap. Strings go first, so a `//`
/// inside a URL is not taken for a comment; then block and line comments.
String withoutComments(String source) {
  final noStrings = source
      .replaceAll(RegExp(r"'''[\s\S]*?'''"), "''")
      .replaceAll(RegExp(r'"""[\s\S]*?"""'), '""')
      .replaceAll(RegExp(r"'(?:\\.|[^'\\\n])*'"), "''")
      .replaceAll(RegExp(r'"(?:\\.|[^"\\\n])*"'), '""');
  return noStrings
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .split('\n')
      .map((line) {
        final at = line.indexOf('//');
        return at < 0 ? line : line.substring(0, at);
      })
      .join('\n');
}

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
    // #2386 — a part file is its library: a screen split across part
    // files is still one presentation file reaching a repository.
    final list = found[feature] ??= [];
    final library = libraryPathOf(file);
    if (!list.contains(library)) list.add(library);
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

/// The library [file] belongs to: itself, or the file its `part of`
/// names (#2386).
String libraryPathOf(File file) {
  final m = RegExp(r"^part of '([^']+)';", multiLine: true)
      .firstMatch(file.readAsStringSync());
  if (m == null) return file.path;
  final dir = file.parent.path;
  final parts = [...dir.split('/'), ...m.group(1)!.split('/')];
  final out = <String>[];
  for (final p in parts) {
    if (p == '..') {
      out.removeLast();
    } else if (p != '.') {
      out.add(p);
    }
  }
  return out.join('/');
}

// ---- #2495 — the whole feature graph, not only its mutual pairs --------

/// Strongly connected components of size > 1 over the directed feature
/// graph given as `a -> b` keys (Tarjan), each sorted, the list sorted by
/// its first member. A component is a set of features every one of which
/// can reach every other: `money -> members -> workspace -> money` is one
/// even though no two of them import each other.
List<List<String>> stronglyConnected(Iterable<String> edges) {
  final graph = <String, Set<String>>{};
  for (final e in edges) {
    final parts = e.split(' -> ');
    graph.putIfAbsent(parts[0], () => {}).add(parts[1]);
    graph.putIfAbsent(parts[1], () => {});
  }
  var counter = 0;
  final index = <String, int>{}, low = <String, int>{};
  final onStack = <String>{}, stack = <String>[];
  final out = <List<String>>[];
  void visit(String v) {
    index[v] = low[v] = counter++;
    stack.add(v);
    onStack.add(v);
    for (final w in (graph[v]!.toList()..sort())) {
      if (!index.containsKey(w)) {
        visit(w);
        low[v] = low[v]! < low[w]! ? low[v]! : low[w]!;
      } else if (onStack.contains(w)) {
        low[v] = low[v]! < index[w]! ? low[v]! : index[w]!;
      }
    }
    if (low[v] == index[v]) {
      final component = <String>[];
      String w;
      do {
        w = stack.removeLast();
        onStack.remove(w);
        component.add(w);
      } while (w != v);
      if (component.length > 1) out.add(component..sort());
    }
  }

  for (final v in (graph.keys.toList()..sort())) {
    if (!index.containsKey(v)) visit(v);
  }
  return out..sort((a, b) => a.first.compareTo(b.first));
}

/// One shortest cycle through [members] over [edges], as
/// `a -> b -> c -> a`; ties go to the alphabetically first start.
String shortestCycle(Iterable<String> members, Iterable<String> edges) {
  final inside = members.toSet();
  final next = <String, List<String>>{};
  for (final e in edges) {
    final p = e.split(' -> ');
    if (inside.contains(p[0]) && inside.contains(p[1])) {
      (next[p[0]] ??= []).add(p[1]);
    }
  }
  List<String>? best;
  for (final start in inside.toList()..sort()) {
    final prev = <String, String>{};
    final queue = [start];
    var found = false;
    for (var i = 0; i < queue.length && !found; i++) {
      for (final w in (next[queue[i]] ?? <String>[])..sort()) {
        if (w == start) {
          final path = [queue[i]];
          while (path.first != start) {
            path.insert(0, prev[path.first]!);
          }
          if (best == null || path.length < best.length) best = path;
          found = true;
          break;
        }
        if (!prev.containsKey(w) && w != start) {
          prev[w] = queue[i];
          queue.add(w);
        }
      }
    }
  }
  if (best == null) return '';
  return [...best, best.first].join(' -> ');
}

/// Imports from `lib/core` (outside `core/demo`, which mirrors the
/// features by design) into a feature, counted per `core/<area>`.
Map<String, int> coreToFeatureImports(Iterable<File> files) {
  final counts = <String, int>{};
  for (final file in files) {
    final parts = file.path.split('/');
    if (parts.length < 4 || parts[0] != 'lib' || parts[1] != 'core') continue;
    if (parts[2] == 'demo') continue;
    for (final m in importRe.allMatches(file.readAsStringSync())) {
      final imp = m.group(1)!;
      final resolved = imp.startsWith('package:deskilo/')
          ? imp.replaceFirst('package:deskilo/', 'lib/')
          : resolveRelative(file.path.substring(0, file.path.lastIndexOf('/')), imp);
      if (resolved != null && featureOf(resolved) != null) {
        counts.update('core/${parts[2]}', (n) => n + 1, ifAbsent: () => 1);
      }
    }
  }
  return counts;
}

/// The `a -> b` pairs of [counts] that import UPWARD in [layers] (an
/// ordered list, lowest first; a feature in no layer is ignored), with
/// their import counts.
Map<String, int> layerViolations(
  Map<String, int> counts,
  List<List<String>> layers,
) {
  final rank = <String, int>{
    for (var i = 0; i < layers.length; i++)
      for (final f in layers[i]) f: i,
  };
  return {
    for (final e in counts.entries)
      if (rank[e.key.split(' -> ')[0]] != null &&
          rank[e.key.split(' -> ')[1]] != null &&
          rank[e.key.split(' -> ')[0]]! < rank[e.key.split(' -> ')[1]]!)
        e.key: e.value,
  };
}
