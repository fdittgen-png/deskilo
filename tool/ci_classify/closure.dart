// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3475 -- the Dart the database job can reach, proven from the tree.
//
// The classifier used to stand the database job down only for a positive list
// of path prefixes; every change under `lib/**/domain`, `lib/**/data` or
// `packages/**` ran its ~20 minutes, though the job executes only a few Dart
// entry points (the topology consumers and the repository's own tools). This
// file computes the TRANSITIVE IMPORT CLOSURE of those entry points from the
// tree being validated: a changed Dart file outside it cannot change what the
// database job does.
//
// A proof, not an estimate -- every doubt is a [DbClosure.problem], and a
// problem selects the full run (the caller never treats a problem as an empty
// closure):
//   * an entry point the job invokes that this file does not know (the job's
//     test and `dart run` invocations, and those of the scripts it runs, are
//     read from the workflow itself and must all be entry points);
//   * an import, export or part whose target is not a file of the repository
//     (a `package:deskilo*` URI that resolves to nothing, a relative path that
//     does not exist);
//   * a source file that cannot be read, or a directive it cannot parse.
// External packages (`dart:`, hosted packages) are not repository files: they
// change only through pubspec.yaml / pubspec.lock, and those already select
// everything in classify.dart.
//
// Pure `dart:` -- the classifier runs on a runner that has only the Dart SDK.
import 'dart:io';

/// What the database job can reach, or why that could not be proven.
class DbClosure {
  const DbClosure(this.files, this.problem);

  /// Repository-relative paths of every Dart file reachable from the entry
  /// points (the entry points included).
  final Set<String> files;

  /// The first doubt, or null when [files] is a proven closure.
  final String? problem;

  bool get proven => problem == null;
}

/// The directories the Dart files the database job runs must be under: the
/// topology consumers (the Flutter test runner) and the tools (`dart run`). A
/// file outside them is a problem (see [invocationProblem]), never ignored.
const dbEntryRoots = ['test/topology/', 'tool/'];

final _skippable = RegExp(r'(?:\s+|//[^\n]*|/\*.*?\*/)+', dotAll: true);
final _headerDirective = RegExp(
  r'(import|export|part|library)\b(?!\s+of\b)([^;]*?);',
  dotAll: true,
);
final _partOf = RegExp(r'part\s+of\b[^;]*;', dotAll: true);
final _quoted = RegExp(r'''(['"])(.*?)\1''');

/// Every URI the directives of [source] name (a conditional import names
/// several). Only the HEADER is read -- Dart requires directives before any
/// declaration -- so an `import` inside a string (a code generator's template)
/// is not mistaken for one. `part of` is skipped: the owner reaches its parts,
/// not the reverse.
List<String> directiveUris(String source) {
  final uris = <String>[];
  var pos = 0;
  while (true) {
    final skip = _skippable.matchAsPrefix(source, pos);
    if (skip != null) pos = skip.end;
    final partOf = _partOf.matchAsPrefix(source, pos);
    if (partOf != null) {
      pos = partOf.end;
      continue;
    }
    final m = _headerDirective.matchAsPrefix(source, pos);
    if (m == null) break;
    pos = m.end;
    if (m.group(1) == 'library') continue;
    for (final q in _quoted.allMatches(m.group(2)!)) {
      uris.add(q.group(2)!);
    }
  }
  return uris;
}

/// The repository path [uri] (written in [from]) names: `path` null for an
/// external one (`dart:`, a hosted package), or a `problem`.
({String? path, String? problem}) resolveUri(
  String repo,
  String from,
  String uri,
) {
  if (uri.startsWith('dart:')) return (path: null, problem: null);
  if (uri.startsWith('package:')) {
    final rest = uri.substring('package:'.length);
    final slash = rest.indexOf('/');
    if (slash <= 0) {
      return (path: null, problem: '$from: malformed package URI "$uri"');
    }
    final name = rest.substring(0, slash);
    final tail = rest.substring(slash + 1);
    if (name == 'deskilo') return (path: 'lib/$tail', problem: null);
    if (Directory('$repo/packages/$name').existsSync()) {
      return (path: 'packages/$name/lib/$tail', problem: null);
    }
    return (path: null, problem: null); // a hosted package
  }
  if (uri.contains(':')) {
    return (
      path: null,
      problem: '$from: a URI scheme this proof does not follow: "$uri"',
    );
  }
  final dir = from.contains('/')
      ? from.substring(0, from.lastIndexOf('/'))
      : '';
  final parts = <String>[...dir.split('/').where((p) => p.isNotEmpty)];
  for (final seg in uri.split('/')) {
    if (seg == '..') {
      if (parts.isEmpty) {
        return (path: null, problem: '$from: "$uri" leaves the repository');
      }
      parts.removeLast();
    } else if (seg != '.' && seg.isNotEmpty) {
      parts.add(seg);
    }
  }
  return (path: parts.join('/'), problem: null);
}

/// The closure of [entries] in the tree at [repo].
DbClosure computeClosure(String repo, List<String> entries) {
  final seen = <String>{};
  final queue = <String>[...entries];
  while (queue.isNotEmpty) {
    final path = queue.removeLast();
    if (!seen.add(path)) continue;
    final file = File('$repo/$path');
    final String source;
    try {
      if (!file.existsSync()) {
        return DbClosure(
          seen,
          '$path is named by an import but is not a file of the repository',
        );
      }
      source = file.readAsStringSync();
    } on Object catch (e) {
      // not only a FileSystemException: a file that is not valid UTF-8 throws a
      // FormatException, and a crash here would turn every check red
      return DbClosure(seen, '$path cannot be read: $e');
    }
    for (final uri in directiveUris(source)) {
      final r = resolveUri(repo, path, uri);
      if (r.problem != null) return DbClosure(seen, r.problem);
      final target = r.path;
      if (target == null) continue;
      if (!target.endsWith('.dart')) {
        return DbClosure(seen, '$path: "$uri" is not a Dart file');
      }
      if (!seen.contains(target)) queue.add(target);
    }
  }
  return DbClosure(seen, null);
}

/// The text of the database job in [workflow] (quality.yml): from the job key
/// to the next top-level job key. Null when it cannot be found.
String? databaseJobText(String workflow) {
  final lines = workflow.split('\n');
  final start = lines.indexWhere(
    (l) => RegExp(r'^  database:\s*$').hasMatch(l),
  );
  if (start < 0) return null;
  var end = lines.length;
  for (var i = start + 1; i < lines.length; i++) {
    if (RegExp(r'^  [A-Za-z_][\w-]*:\s*$').hasMatch(lines[i])) {
      end = i;
      break;
    }
  }
  return lines.sublist(start, end).join('\n');
}

/// Options whose next word is their value, not a file (`--reporter expanded`).
const _optionsWithValue = {
  '--reporter',
  '--file-reporter',
  '--concurrency',
  '--timeout',
  '--name',
  '--plain-name',
  '--tags',
  '--exclude-tags',
  '--platform',
};

final _scriptRef = RegExp(r'scripts/[\w./-]+\.(?:sh|py)');

/// The command words after which a Dart file or a package executable follows.
final _runners = RegExp(
  r'''(?:^|[\s;&|(])((?:flutter\s+test|dart\s+run|dart))\s+([^\n;&|<>`()]*)''',
);

/// The Dart files the database job runs, read from the workflow itself, or the
/// reason they could not be read completely: every test run, `dart run` and
/// `dart <file>` the job (and the scripts it runs, followed recursively) must
/// name a Dart file under [dbEntryRoots] that exists in the tree. A target it
/// cannot read (a variable, a directory, an executable of a package) is a
/// problem: no entry point would cover it.
({Set<String> entries, String? problem}) invokedEntryPoints(String repo) {
  final entries = <String>{};
  final p = _scanInvocations(repo, entries);
  return (entries: entries, problem: p);
}

/// Why the job's Dart invocations are not all inside the entry roots, or null.
String? invocationProblem(String repo) => invokedEntryPoints(repo).problem;

String? _scanInvocations(String repo, Set<String> entries) {
  final workflow = File('$repo/.github/workflows/quality.yml');
  if (!workflow.existsSync()) return 'quality.yml is not in the tree';
  final job = databaseJobText(workflow.readAsStringSync());
  if (job == null) return 'the database job was not found in quality.yml';
  final texts = <String, String>{'quality.yml database job': job};
  final queue = [for (final m in _scriptRef.allMatches(job)) m.group(0)!];
  final seen = <String>{};
  while (queue.isNotEmpty) {
    final script = queue.removeLast();
    if (!seen.add(script)) continue;
    final f = File('$repo/$script');
    if (!f.existsSync()) {
      return '$script is run by the database job but is not in the tree';
    }
    final text = f.readAsStringSync();
    texts[script] = text;
    for (final m in _scriptRef.allMatches(text)) {
      queue.add(m.group(0)!);
    }
  }
  for (final e in texts.entries) {
    for (final line in e.value.split('\n')) {
      final code = line.trimLeft();
      if (code.startsWith('#')) continue;
      for (final m in _runners.allMatches(code)) {
        final runner = m.group(1)!.replaceAll(RegExp(r'\s+'), ' ');
        final args = m
            .group(2)!
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty);
        // `dart pub get`, `dart --version`, `dart analyze`, `dart format`
        // run no repository code
        final isTestOrRun = runner != 'dart';
        var any = false;
        var skipValue = false;
        for (final raw in args) {
          final t = raw.replaceAll(RegExp(r'''["']+$'''), '');
          if (skipValue) {
            skipValue = false;
            continue;
          }
          if (t.startsWith('-')) {
            skipValue = _optionsWithValue.contains(t);
            continue;
          }
          if (t.contains(r'$') || t.contains('"') || t.contains("'")) {
            return '${e.key}: `${m.group(0)!.trim()}` has an argument this proof cannot resolve: $t';
          }
          if (t.endsWith('.dart')) {
            any = true;
            if (!dbEntryRoots.any(t.startsWith)) {
              return '${e.key}: runs $t, which is not under ${dbEntryRoots.join(' or ')}';
            }
            if (!File('$repo/$t').existsSync()) {
              return '${e.key}: runs $t, which is not in the tree';
            }
            entries.add(t);
            // after the program of `dart run` / `dart` everything is its own
            // argument, never another entry point
            if (!isTestOrRun || runner == 'dart run') break;
            continue;
          }
          if (runner == 'dart' &&
              RegExp(r'^(pub|analyze|format|fix|compile)$').hasMatch(t)) {
            break;
          }
          if (runner == 'dart' &&
              RegExp(r'^(get|upgrade|run|test)$').hasMatch(t)) {
            continue;
          }
          if (isTestOrRun || t.contains('/')) {
            return '${e.key}: `${m.group(0)!.trim()}` names "$t", which is not a Dart file under ${dbEntryRoots.join(' or ')}';
          }
        }
        if (isTestOrRun && !any) {
          return '${e.key}: `${m.group(0)!.trim()}` names no Dart file';
        }
      }
    }
  }
  return null;
}

/// The closure of the database job's entry points in the tree at [repo]: a
/// problem when the invocations are not all entry points or when the import
/// graph cannot be followed completely.
DbClosure databaseClosure(String repo) {
  final invoked = invokedEntryPoints(repo);
  if (invoked.problem != null) return DbClosure(const {}, invoked.problem);
  if (invoked.entries.isEmpty) {
    return const DbClosure(
      {},
      'the database job runs no Dart file this proof can name',
    );
  }
  return computeClosure(repo, invoked.entries.toList()..sort());
}
