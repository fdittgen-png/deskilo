// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1447 — run the generators this change implicates, then say whether
// anything drifted.
//
//   dart run tool/preflight.dart            # against origin/master
//   dart run tool/preflight.dart --base HEAD~1
//   dart run tool/preflight.dart --list     # decide only, run nothing
//
// It is local and read-only towards every backend: it runs generators
// and `git`, and it never merges, closes, assigns, dispatches or writes
// to a database. Exit 0 when nothing drifted, 1 when a generator wrote
// something the commit does not have, 2 when a generator failed.
import 'dart:io';

import 'preflight/preflight.dart';

List<String> _changedPaths(String base) {
  final tracked = Process.runSync('git', [
    'diff',
    '--name-only',
    '--diff-filter=d',
    base,
  ]);
  final untracked = Process.runSync('git', [
    'ls-files',
    '--others',
    '--exclude-standard',
  ]);
  return [
    ..._lines(tracked.stdout as String),
    ..._lines(untracked.stdout as String),
  ];
}

Iterable<String> _lines(String s) =>
    s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);

/// `git status --porcelain` prints two status columns, a space, then the
/// path — so the path starts at column 3 of the RAW line. Trimming first
/// eats the status and then three characters of the name.
Set<String> _dirty() =>
    (Process.runSync('git', ['status', '--porcelain']).stdout as String)
        .split('\n')
        .where((l) => l.length > 3)
        .map((l) => l.substring(3).trim())
        .map((l) => l.contains(' -> ') ? l.split(' -> ').last : l)
        .toSet();

int main(List<String> args) {
  final i = args.indexOf('--base');
  final base = i >= 0 && i + 1 < args.length ? args[i + 1] : 'origin/master';
  final listOnly = args.contains('--list');

  final paths = _changedPaths(base);
  if (paths.isEmpty) {
    stdout.writeln('preflight v$preflightVersion: nothing changed against $base');
    return 0;
  }
  final steps = preflightSteps(paths);
  stdout.writeln('preflight v$preflightVersion: ${paths.length} changed '
      'file(s) against $base select ${steps.length} generator(s)');
  if (steps.isEmpty) return 0;

  for (final s in steps) {
    stdout.writeln('  ${s.command}   (${s.because})');
  }
  if (listOnly) return 0;

  final before = _dirty();
  for (final s in steps) {
    stdout.writeln('\n\$ ${s.command}');
    final parts = s.command.split(' ');
    final r = Process.runSync(parts.first, parts.skip(1).toList());
    stdout.write(r.stdout);
    if (r.exitCode != 0) {
      stderr.write(r.stderr);
      stderr.writeln('preflight: ${s.command} failed (${r.exitCode})');
      return 2;
    }
  }

  final drifted = _dirty().difference(before);
  if (drifted.isEmpty) {
    stdout.writeln('\npreflight: every generated tree already matches its '
        'source — nothing to commit that CI would have found.');
    return 0;
  }
  stdout.writeln('\npreflight: ${drifted.length} generated file(s) were out '
      'of date and have been rewritten. Commit them:');
  for (final f in drifted.toList()..sort()) {
    stdout.writeln('  $f');
  }
  return 1;
}
