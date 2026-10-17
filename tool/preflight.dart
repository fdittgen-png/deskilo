// SPDX-License-Identifier: AGPL-3.0-or-later
// Select existing generators from changed inputs; --list executes none.
// Exit 0: selected generators made no changes (or none were selected).
// Exit 1: generation changed content; exit 2: discovery or execution failed.
// This is local tooling, not evidence that the full CI suite passed.
import 'dart:io';

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
