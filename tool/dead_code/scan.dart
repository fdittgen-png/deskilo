// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2383 — the dead-code scan: every public top-level declaration in `lib/`
// that nothing references (UNREFERENCED), and every one that only tests
// reference (TEST_ONLY).
//
// A reference is an identifier token outside comments, in any hand-written
// Dart file or in a generated file that stands on its own. A generated
// `part of` file (`.g.dart`, `.freezed.dart`) never counts: it mentions the
// symbol it was generated from, which proves nothing. A Riverpod function
// `foo` or notifier class `Foo` is also referenced by `fooProvider`. Uses
// inside the declaration's own span (a constructor naming its class, a
// recursive call) do not count; uses elsewhere in the same file do — a
// symbol used only in its own file is over-exposed (#2384), not dead.
//
// Matching is by name, so a name shared with another symbol hides a dead
// declaration (a miss, never a false alarm). Text inside string literals
// counts as a reference, for the same reason; but a string never DECLARES
// anything, so a SQL line at column 0 (`select current_setting(...)`) is
// not mistaken for a Dart function.
import 'dart:io';

part 'surface.dart';

/// Why a declaration is listed.
enum DeadCodeKind {
  /// Nothing anywhere names it.
  unreferenced,

  /// Only files under `test/` name it.
  testOnly,
}

/// One listed declaration.
class DeadCodeFinding {
  const DeadCodeFinding(this.path, this.line, this.name, this.kind);

  final String path;
  final int line;
  final String name;
  final DeadCodeKind kind;

  /// The allow-list key: `path::name`.
  String get key => '$path::$name';

  @override
  String toString() => '$path:$line: $name (${kind.name})';
}

/// Directories whose Dart files are production readers of `lib/`.
const productionRoots = ['lib', 'tool', 'integration_test', 'packages', 'bin'];

/// Scans the repository at [root] (the directory holding `lib/` and
/// `test/`) and returns the findings sorted by path and line.
List<DeadCodeFinding> scanDeadCode(String root) {
  final corpus = _Corpus(root);
  final sources = corpus.sources;
  final index = corpus.index;

  final findings = <DeadCodeFinding>[];
  for (final s in sources.values) {
    if (!s.path.startsWith('lib/') || s.isGenerated) continue;
    if (s.path.startsWith('lib/l10n/')) continue;
    for (final d in s.declarations) {
      var production = false;
      var test = false;
      for (final name in _referenceNames(d.name)) {
        for (final e in (index[name] ?? const <String, List<int>>{}).entries) {
          final uses = e.key == s.path
              ? e.value.where((l) => l < d.start || l > d.end)
              : e.value;
          if (uses.isEmpty) continue;
          if (e.key.startsWith('test/')) {
            test = true;
          } else {
            production = true;
          }
        }
      }
      if (production) continue;
      findings.add(
        DeadCodeFinding(
          s.path,
          d.start + 1,
          d.name,
          test ? DeadCodeKind.testOnly : DeadCodeKind.unreferenced,
        ),
      );
    }
  }
  findings.sort((a, b) {
    final byPath = a.path.compareTo(b.path);
    return byPath != 0 ? byPath : a.line.compareTo(b.line);
  });
  return findings;
}

/// Every Dart file of the production roots and `test/`, and the index of
/// the names they mention (both modes read it).
class _Corpus {
  _Corpus(String root) {
    for (final top in [...productionRoots, 'test']) {
      final dir = Directory('$root/$top');
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.substring(root.length + 1).replaceAll(r'\', '/');
        sources[rel] = _Source(rel, f.readAsStringSync());
      }
    }
    for (final s in sources.values) {
      if (s.isGeneratedPart) continue;
      final lines = s.referenceText.split('\n');
      for (var i = 0; i < lines.length; i++) {
        for (final m in _identifier.allMatches(lines[i])) {
          ((index[m.group(1)!] ??= {})[s.path] ??= []).add(i);
        }
      }
    }
  }

  final sources = <String, _Source>{};

  /// name -> files (with the lines) that mention it.
  final index = <String, Map<String, List<int>>>{};
}

final _identifier = RegExp(r'\$?([A-Za-z_][A-Za-z0-9_$]*)');

/// The tokens that reference a declaration called [name].
List<String> _referenceNames(String name) {
  final lower = name[0].toLowerCase() + name.substring(1);
  return {name, '${name}Provider', '${lower}Provider'}.toList();
}

class _Declaration {
  _Declaration(this.name, this.start, this.annotations, {this.isType = false});

  final String name;

  /// The annotation lines directly above it (`@visibleForTesting`, ...).
  final List<String> annotations;

  /// A class, enum, mixin, typedef or extension type.
  final bool isType;

  /// 0-based first and last line of the declaration's span.
  final int start;
  int end = 0;
}

class _Source {
  _Source(this.path, String text) {
    isGeneratedPart =
        isGenerated && RegExp(r'^part of\b', multiLine: true).hasMatch(text);
    final lexed = _lex(text);
    referenceText = lexed.withStrings;
    codeLines = lexed.codeOnly.split('\n');
    declarations = _declarations(lexed.codeOnly, text);
  }

  final String path;
  late final bool isGeneratedPart;
  late final String referenceText;

  /// Comments and string contents blanked, by line.
  late final List<String> codeLines;
  late final List<_Declaration> declarations;

  bool get isGenerated =>
      path.endsWith('.g.dart') || path.endsWith('.freezed.dart');
}

// A top-level declaration starts at column 0. Group 1 is the name.
final _typeDecl = RegExp(
  r'^(?:(?:abstract|sealed|final|base|interface|mixin)\s+)*'
  r'(?:class|enum|mixin|typedef|extension\s+type)\s+([A-Za-z_$][\w$]*)',
);
// An extension is used through its members, never by its name: it opens
// a span but is not listed.
final _extensionDecl = RegExp(r'^extension\s');
// `Type name(`, `Type get name`, `name(` with no return type, `Type name =`.
final _memberDecl = RegExp(
  r'^(?:external\s+)?(?:(?:const|final|var|late)\s+)*'
  r'(?:(?:[A-Za-z_$][\w$.]*(?:<[^=;{]*>)?|\([^)]*\))\??'
  r'(?:\s+Function\([^)]*\)\??)?\s+)?'
  r'(?:get\s+)?([A-Za-z_$][\w$]*)\s*(?:<[^>(]*>)?\s*(?:\(|=|;|=>)',
);
const _notDeclarations = {
  'import',
  'export',
  'part',
  'library',
  'main',
  'return',
  'if',
  'for',
  'while',
  'switch',
  'await',
  'assert',
  'throw',
  'get',
  'set',
  'operator',
};

List<_Declaration> _declarations(String code, String raw) {
  final lines = code.split('\n');
  final rawLines = raw.split('\n');
  final out = <_Declaration>[];
  var entryPoint = false;
  var annotations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty || line.startsWith(' ') || line.startsWith('\t')) {
      continue;
    }
    if (line.startsWith('@')) {
      if (rawLines[i].contains('vm:entry-point')) entryPoint = true;
      annotations.add(rawLines[i].trim());
      continue;
    }
    final m =
        _typeDecl.firstMatch(line) ??
        (_extensionDecl.hasMatch(line) ? null : _memberDecl.firstMatch(line));
    final starts = m != null || RegExp(r'^[A-Za-z]').hasMatch(line);
    if (starts && out.isNotEmpty && out.last.end == 0) out.last.end = i - 1;
    if (m == null) {
      entryPoint = false;
      // A header split over lines (`const Map<…>`, then the name) keeps
      // the annotations above it.
      if (RegExp(r'[;}]\s*$').hasMatch(line)) annotations = <String>[];
      continue;
    }
    final name = m.group(1)!;
    if (!entryPoint &&
        !name.startsWith('_') &&
        !_notDeclarations.contains(name)) {
      out.add(
        _Declaration(name, i, annotations, isType: _typeDecl.hasMatch(line)),
      );
    } else if (out.isNotEmpty && out.last.end == 0) {
      out.last.end = i - 1;
    }
    entryPoint = false;
    annotations = <String>[];
  }
  if (out.isNotEmpty && out.last.end == 0) out.last.end = lines.length - 1;
  return out;
}

class _Lexed {
  _Lexed(this.withStrings, this.codeOnly);

  /// Comments blanked; string contents kept.
  final String withStrings;

  /// Comments and string contents blanked (interpolated code kept).
  final String codeOnly;
}

/// Blanks comments (and, in [codeOnly], string contents) while keeping every
/// newline, so line numbers survive. Handles raw, triple-quoted and nested
/// interpolated strings.
_Lexed _lex(String src) {
  final a = StringBuffer();
  final b = StringBuffer();
  void both(String c) {
    a.write(c);
    b.write(c);
  }

  void blank(String c, {bool keepInA = false}) {
    final space = c == '\n' ? '\n' : ' ';
    a.write(keepInA ? c : space);
    b.write(space);
  }

  // Stack of open strings; an int entry counts braces of an interpolation.
  final strings = <_Str>[];
  final braces = <int>[];
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    final inString = strings.isNotEmpty && braces.length < strings.length;
    if (inString) {
      final s = strings.last;
      if (!s.raw && c == r'\' && i + 1 < src.length) {
        blank(c, keepInA: true);
        blank(src[i + 1], keepInA: true);
        i += 2;
        continue;
      }
      if (src.startsWith(s.quote, i)) {
        for (final q in s.quote.split('')) {
          both(q);
        }
        i += s.quote.length;
        strings.removeLast();
        continue;
      }
      if (!s.raw && c == r'$' && i + 1 < src.length && src[i + 1] == '{') {
        both(r'$');
        both('{');
        braces.add(0);
        i += 2;
        continue;
      }
      if (!s.raw && c == r'$') {
        // `$name` — the name is code.
        both(' ');
        i++;
        while (i < src.length && RegExp(r'[\w]').hasMatch(src[i])) {
          both(src[i]);
          i++;
        }
        continue;
      }
      blank(c, keepInA: true);
      i++;
      continue;
    }
    if (c == '/' && i + 1 < src.length && src[i + 1] == '/') {
      while (i < src.length && src[i] != '\n') {
        blank(src[i]);
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < src.length && src[i + 1] == '*') {
      var depth = 0;
      while (i < src.length) {
        if (src.startsWith('/*', i)) {
          depth++;
          blank('/');
          blank('*');
          i += 2;
        } else if (src.startsWith('*/', i)) {
          depth--;
          blank('*');
          blank('/');
          i += 2;
          if (depth == 0) break;
        } else {
          blank(src[i]);
          i++;
        }
      }
      continue;
    }
    if (c == '{' && braces.isNotEmpty) braces.last++;
    if (c == '}' && braces.isNotEmpty) {
      if (braces.last == 0) {
        braces.removeLast();
        both(c);
        i++;
        continue;
      }
      braces.last--;
    }
    if (c == "'" || c == '"') {
      final raw = i > 0 && src[i - 1] == 'r';
      final triple = src.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      for (final q in quote.split('')) {
        both(q);
      }
      i += quote.length;
      strings.add(_Str(quote, raw: raw));
      continue;
    }
    both(c);
    i++;
  }
  return _Lexed(a.toString(), b.toString());
}

class _Str {
  _Str(this.quote, {required this.raw});

  final String quote;
  final bool raw;
}
