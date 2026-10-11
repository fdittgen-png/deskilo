// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2384 — the public-surface scan, the dead-code scan's second mode: every
// public top-level declaration in `lib/` that no other production file
// names. Dart's visibility unit is the library, so a declaration used by
// its own file alone is `_private` to it; one that tests also read carries
// `@visibleForTesting`, the idiom for exactly that.
//
// A declaration is NOT listed when:
// - another file in `lib/`, `tool/`, `packages/`, `bin/` or
//   `integration_test/` names it;
// - its own generated part (`.g.dart`, `.freezed.dart`) names it — a
//   provider's or a model's generated API is built from that name;
// - it is a type named in the public face of a declaration that stays
//   public (a field, a parameter, a return type, a public extension):
//   making it private would only move the exposure into
//   `library_private_types_in_public_api`;
// - nothing at all names it — that is dead code, the first mode's job.
//
// Matching is by name, like the first mode: a shared name hides a finding
// (a miss, never a false alarm).
part of 'scan.dart';

/// Why a declaration is listed.
enum SurfaceKind {
  /// Only its own file names it: make it private.
  ownFile,

  /// Its own file and tests name it: annotate it `@visibleForTesting`.
  testsOnly,
}

/// One over-exposed declaration.
class SurfaceFinding {
  const SurfaceFinding(this.path, this.line, this.name, this.kind);

  final String path;
  final int line;
  final String name;
  final SurfaceKind kind;

  /// The allow-list key: `path::name`.
  String get key => '$path::$name';

  @override
  String toString() => '$path:$line: $name (${kind.name})';
}

/// Scans the repository at [root] and returns the over-exposed
/// declarations, sorted by path and line.
List<SurfaceFinding> scanPublicSurface(String root) {
  final corpus = _Corpus(root);
  final out = <SurfaceFinding>[];
  for (final s in corpus.sources.values) {
    if (!s.path.startsWith('lib/') || s.isGenerated) continue;
    if (s.path.startsWith('lib/l10n/')) continue;
    final production = <_Declaration>{};
    final tests = <_Declaration>{};
    final own = <_Declaration>{};
    for (final d in s.declarations) {
      for (final name in _referenceNames(d.name)) {
        final files = corpus.index[name] ?? const <String, List<int>>{};
        for (final e in files.entries) {
          if (e.key == s.path) {
            if (e.value.any((l) => l < d.start || l > d.end)) own.add(d);
          } else if (e.key.startsWith('test/')) {
            tests.add(d);
          } else {
            production.add(d);
          }
        }
      }
    }
    final generated = [
      for (final ext in const ['.g.dart', '.freezed.dart'])
        corpus
                .sources[s.path.replaceFirst(RegExp(r'\.dart$'), ext)]
                ?.referenceText ??
            '',
    ].join('\n');
    final inGenerated = {
      for (final d in s.declarations)
        if (_mentions(generated, d.name)) d,
    };
    final forTests = _exposed(s, {...production, ...inGenerated});
    final forAll = _exposed(s, {...production, ...inGenerated, ...tests});
    for (final d in s.declarations) {
      if (production.contains(d) || !own.contains(d)) continue;
      if (tests.contains(d)) {
        if (forTests.contains(d) ||
            d.annotations.any((a) => a.startsWith('@visibleForTesting'))) {
          continue;
        }
        out.add(
          SurfaceFinding(s.path, d.start + 1, d.name, SurfaceKind.testsOnly),
        );
      } else if (!forAll.contains(d)) {
        out.add(
          SurfaceFinding(s.path, d.start + 1, d.name, SurfaceKind.ownFile),
        );
      }
    }
  }
  out.sort((a, b) {
    final byPath = a.path.compareTo(b.path);
    return byPath != 0 ? byPath : a.line.compareTo(b.line);
  });
  return out;
}

bool _mentions(String text, String name) =>
    text.isNotEmpty &&
    RegExp('(?<![\\w\$])${RegExp.escape(name)}(?![\\w\$])').hasMatch(text);

/// [seeds], and every type named in the public face of one of them or of a
/// public extension, to a fixed point.
Set<_Declaration> _exposed(_Source s, Set<_Declaration> seeds) {
  final extensions = _publicExtensions(s.codeLines);
  final reachable = {
    ...seeds,
    for (final d in s.declarations)
      if (d.isType && extensions.any((e) => _mentions(e, d.name))) d,
  };
  var grew = true;
  while (grew) {
    grew = false;
    for (final d in s.declarations) {
      if (!d.isType || reachable.contains(d)) continue;
      final named = reachable.any(
        (r) => r != d && _mentions(_face(s.codeLines, r), d.name),
      );
      if (named) {
        reachable.add(d);
        grew = true;
      }
    }
  }
  return reachable;
}

/// What another library sees of [d]: a type's whole span (an
/// over-approximation: private members count too), or a function's or
/// variable's signature up to its body or initializer.
String _face(List<String> code, _Declaration d) {
  final text = code.sublist(d.start, d.end + 1).join('\n');
  if (d.isType) return text;
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '(' || c == '[' || c == '<') depth++;
    if (c == ')' || c == ']' || (c == '>' && (i == 0 || text[i - 1] != '='))) {
      depth--;
    }
    if (depth <= 0 && (c == '{' || c == ';' || c == '=')) {
      return text.substring(0, i);
    }
  }
  return text;
}

/// The spans of the named public extensions: their members are surface.
List<String> _publicExtensions(List<String> code) {
  final out = <String>[];
  for (var i = 0; i < code.length; i++) {
    final m = RegExp(r'^extension\s+([A-Za-z$][\w$]*)').firstMatch(code[i]);
    if (m == null || m.group(1) == 'type' || m.group(1) == 'on') continue;
    var end = i + 1;
    while (end < code.length && !RegExp(r'^[A-Za-z@]').hasMatch(code[end])) {
      end++;
    }
    out.add(code.sublist(i, end).join('\n'));
  }
  return out;
}
