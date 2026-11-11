// SPDX-License-Identifier: AGPL-3.0-or-later
// Select existing generators from changed inputs; --list executes none.
// Exit 0: selected generators made no changes (or none were selected).
// Exit 1: generation changed content; exit 2: discovery or execution failed.
// This is local tooling, not evidence that the full CI suite passed.
import 'dart:convert';
import 'dart:io';

import 'preflight/affected_tests.dart';
import 'preflight/git_state.dart';
import 'preflight/preflight.dart';

void main(List<String> args) => exitCode = run(args);

int run(List<String> args, {
  String? workingDirectory,
  PreflightProcess execute = runPreflightProcess,
}) {
  try {
    var base = 'origin/master';
    var listOnly = false;
    var hasBase = false;
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--list' && !listOnly) {
        listOnly = true;
      } else if (args[i] == '--base' && !hasBase && i + 1 < args.length) {
        base = args[++i];
        hasBase = true;
      } else {
        throw const FormatException('usage: preflight [--base REF] [--list]');
      }
    }
    final initial = PreflightGit(workingDirectory ?? Directory.current.path, execute);
    final root = initial.text(['rev-parse', '--show-toplevel'])
        .replaceFirst(RegExp(r'\r?\n$'), '');
    final git = PreflightGit(root, execute);
    final paths = git.changedPaths(base);
    if (listOnly) {
      _listTests(root, paths, (path) {
        try {
          return git.text(['show', '$base:$path']);
        } on Object {
          return null; // a new file has no text before
        }
      });
    }
    if (paths.isEmpty) {
      stdout.writeln('preflight v$preflightVersion: no changed inputs; no generators run');
      return 0;
    }
    final steps = preflightSteps(paths, generated: git.generatedPaths());
    stdout.writeln('preflight v$preflightVersion: ${paths.length} changed '
        'file(s) select ${steps.length} generator(s)');
    for (final s in steps) {
      stdout.writeln('  ${s.command}   (${s.because})');
    }
    if (listOnly || steps.isEmpty) return 0;

    final before = git.snapshot();
    for (final s in steps) {
      stdout.writeln('\n\$ ${s.command}');
      // These commands come only from the existing trusted selector. No shell.
      final parts = s.command.split(' ');
      final result = execute(parts.first, parts.skip(1).toList(), root);
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      if (result.exitCode != 0) {
        stderr.writeln('preflight: ${s.command} failed (${result.exitCode})');
        return 2;
      }
    }
    final drifted = changedFingerprints(before, git.snapshot());
    if (drifted.isEmpty) {
      stdout.writeln('preflight: selected generators made no content changes; '
          'review existing edits and run required checks');
      return 0;
    }
    stdout.writeln('preflight: generation changed ${drifted.length} path(s); '
        'review and commit only intended changes:');
    for (final path in drifted) {
      stdout.writeln('  $path');
    }
    return 1;
  } on ProcessException catch (error, stack) {
    stderr.writeln('preflight: command failed: $error\n$stack');
    return 2;
  } on FileSystemException catch (error, stack) {
    stderr.writeln('preflight: fingerprint failed: $error\n$stack');
    return 2;
  } on FormatException catch (error, stack) {
    stderr.writeln('preflight: invalid input: $error\n$stack');
    return 2;
  }
}

/// #3715 -- the tests the branch's diff drags in (the table plus importers).
void _listTests(
  String root,
  Iterable<String> paths,
  String? Function(String path) before,
) {
  // A tree without the table (a fixture, an older checkout) lists nothing and
  // says so; the table's own lint keeps it present in this repository.
  if (!File('$root/tool/preflight/test_map.json').existsSync()) {
    stdout.writeln(
      'tests to run: none listed (no tool/preflight/test_map.json)',
    );
    return;
  }
  final table = readTestMap(File('$root/tool/preflight/test_map.json'));
  // #3751 -- what no local test can stand in for (a replay, a remote run).
  for (final note in notesFor(paths, table)) {
    stdout.writeln('before the pull request opens: $note');
  }
  final sources = readTestSources(root);
  final tests = {
    ...affectedTests(
      paths,
      table,
      sources,
      skipImporters:
          readNoImporterSearch(File('$root/tool/preflight/test_map.json')),
    ),
    ..._staleSentenceTests(root, paths, before, sources),
  }.toList()..sort();
  stdout.writeln('tests to run before the push (beyond the lint folder): '
      '${tests.length}');
  for (final t in tests) {
    stdout.writeln('  $t');
  }
  stdout.writeln('tests to run: ${tests.length}');
}

final _englishFragment = RegExp(r'^lib/l10n/_fragments/[^/]+_en\.arb$');

/// #3752 -- the tests that still assert the old text of a changed English
/// sentence. A fragment that cannot be read either side lists nothing: the
/// list never fails for it.
Set<String> _staleSentenceTests(
  String root,
  Iterable<String> paths,
  String? Function(String path) before,
  Map<String, String> sources,
) {
  final out = <String>{};
  for (final path in paths.where(_englishFragment.hasMatch)) {
    try {
      final old = before(path);
      if (old == null) continue;
      final file = File('$root/$path');
      out.addAll(
        testsOfChangedSentences(
          jsonDecode(old) as Map<String, dynamic>,
          file.existsSync()
              ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
              : const <String, dynamic>{},
          sources,
        ),
      );
    } on FormatException {
      continue;
    }
  }
  return out;
}
