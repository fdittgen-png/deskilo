// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3688 -- a branch brought "up to date" by resetting it onto master keeps its
// old working tree; committed like that, it silently puts every file master
// changed in between back to its earlier content (and reverts the tests of the
// reverted work with it, so the suite stays green). This fails a pull request
// that does that:
//
//   dart run tool/stale_base_guard.dart --head <sha> --base origin/master \
//       --title "<pull request title>"
//
// A file is RESTORED by the branch when its blob at the head equals the blob
// before a recent master commit C (or it is absent at both), and the blob at
// the merge base differs from that. One master commit with at least
// [minRestored] restored files fails the guard. A title starting with
// `revert` is not checked. The exit code is set through `exitCode`.
import 'dart:io';

/// How many first-parent commits of master, up to the merge base, are read.
/// A window, not a business value: older commits are not "recent" any more.
const int recentCommits = 30;

/// How many restored files of one master commit make it a reset, not a
/// coincidence (two files reverted by hand are a normal edit).
const int minRestored = 3;

String _git(List<String> args) {
  final r = Process.runSync('git', args);
  if (r.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${r.stderr}');
  }
  return '${r.stdout}'.trim();
}

/// The blob id of [path] at [ref]; null when the file is absent there.
String? _blob(String ref, String path) {
  final r = Process.runSync('git', ['rev-parse', '--verify', '-q', '$ref:$path']);
  return r.exitCode == 0 ? '${r.stdout}'.trim() : null;
}

/// One master commit the branch undoes.
typedef Restored = ({String hash, String subject, List<String> paths});

/// The master commits whose changes [head] puts back, given [base].
List<Restored> staleBaseFindings({required String head, required String base}) {
  final mergeBase = _git(['merge-base', head, base]);
  final commits = _git([
    'rev-list',
    '--first-parent',
    '-n',
    '$recentCommits',
    mergeBase,
  ]).split('\n').where((l) => l.isNotEmpty);
  final out = <Restored>[];
  for (final c in commits) {
    final parents = _git(['rev-list', '--parents', '-n', '1', c]).split(' ');
    if (parents.length < 2) continue; // the root commit changed nothing
    final before = parents[1];
    final changed = _git(['diff', '--name-only', before, c])
        .split('\n')
        .where((l) => l.isNotEmpty);
    final restored = <String>[];
    for (final f in changed) {
      final atBefore = _blob(before, f);
      if (_blob(head, f) == atBefore && _blob(mergeBase, f) != atBefore) {
        restored.add(f);
      }
    }
    if (restored.length >= minRestored) {
      out.add((
        hash: c.substring(0, 9),
        subject: _git(['log', '-1', '--format=%s', c]),
        paths: restored,
      ));
    }
  }
  return out;
}

void main(List<String> args) {
  String option(String name, String fallback) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final title = option('title', '');
  if (title.trimLeft().toLowerCase().startsWith('revert')) {
    stdout.writeln('stale base guard: a revert is not checked.');
    return;
  }
  final findings = staleBaseFindings(
    head: option('head', 'HEAD'),
    base: option('base', 'origin/master'),
  );
  if (findings.isEmpty) {
    stdout.writeln('stale base guard: no recent master change is undone.');
    return;
  }
  for (final f in findings) {
    stdout.writeln(
      '::error::${f.hash} ${f.subject}: ${f.paths.length} files restored '
      '(${f.paths.take(10).join(', ')}). This branch puts these files back to '
      'their content before ${f.hash}. Merge origin/master into the branch '
      'instead of resetting onto it, or start the title with `revert` if this '
      'is intended.',
    );
  }
  exitCode = 1;
}
