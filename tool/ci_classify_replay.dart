// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3475 -- replays the change classifier over recorded diffs, so the scoped
// verdict can be set beside the recorded outcome of the FULL database job.
//
//   dart run tool/ci_classify_replay.dart <inputs.txt>
//
// One line per diff: `<label> <head sha> <outcome>` where `<outcome>` is what
// the full database job did on it (`success`, `failure`, ...). The diff is
// `merge-base(head, origin/master)..head` (a squash-merged change: pass the
// squash commit and its parent as `<label> <commit> <outcome> <base>`); the
// tree the closure is computed from is the head's, exported with `git archive`.
// The classifier code is THIS checkout's; the tree it reads is the recorded one,
// so an older quality.yml that this version cannot read is a doubt, and a doubt
// is the full run.
//
// REPLAY_NO_CLOSURE=1 replays the path rules alone (what v5 decided), for the
// comparison.
//
// Prints a markdown table: label, files, verdict, reason, recorded outcome.
import 'dart:io';

import 'ci_classify/classify.dart';
import 'ci_classify/closure.dart';

String _git(List<String> args) {
  final r = Process.runSync('git', args, stdoutEncoding: null);
  if (r.exitCode != 0) {
    throw StateError(
      'git ${args.join(' ')} failed: ${String.fromCharCodes(r.stderr as List<int>)}',
    );
  }
  return String.fromCharCodes(r.stdout as List<int>).trim();
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/ci_classify_replay.dart <inputs.txt>');
    exitCode = 2;
    return;
  }
  final scratch = Directory.systemTemp.createTempSync('ci_replay');
  stdout
    ..writeln(
      '| diff | files | database verdict | reason | recorded full database job |',
    )
    ..writeln('|---|---|---|---|---|');
  var scoped = 0, full = 0;
  for (final line in File(args.first).readAsLinesSync()) {
    final f = line.trim().split(RegExp(r'\s+'));
    if (f.length < 3 || line.trim().startsWith('#')) continue;
    final label = f[0], head = f[1], outcome = f[2];
    final base = f.length > 3
        ? f[3]
        : _git(['merge-base', head, 'origin/master']);
    try {
      final diff = Process.runSync('git', [
        'diff',
        '--name-status',
        '-z',
        base,
        head,
      ], stdoutEncoding: null);
      final parsed = pathsFromNameStatus(
        String.fromCharCodes(diff.stdout as List<int>),
      );
      final tree = Directory('${scratch.path}/tree')..createSync();
      final archive = Process.runSync('bash', [
        '-c',
        'git archive $head -- lib packages test tool scripts .github pubspec.yaml 2>/dev/null | tar -x -C "${tree.path}"',
      ]);
      if (archive.exitCode != 0) throw StateError('git archive failed');
      final verdicts = classify(
        ChangeSet(
          paths: parsed.paths,
          baseKnown: true,
          event: 'pull_request',
          problem: parsed.problem,
          closure: Platform.environment['REPLAY_NO_CLOSURE'] == '1'
              ? null
              : () => databaseClosure(tree.path),
        ),
      );
      final v = verdicts.firstWhere((x) => x.discipline == 'database');
      if (v.required) {
        full++;
      } else {
        scoped++;
      }
      final reason = v.reason.replaceAll('|', '/');
      stdout.writeln(
        '| $label | ${parsed.paths.length} | ${v.required ? '**required**' : 'not_applicable'} | ${reason.length > 110 ? '${reason.substring(0, 107)}...' : reason} | $outcome |',
      );
      tree.deleteSync(recursive: true);
    } on Object catch (e) {
      full++;
      stdout.writeln(
        '| $label | ? | **required** | the replay could not read it: $e | $outcome |',
      );
    }
  }
  stdout.writeln('\n$scoped scoped out, $full required.');
  scratch.deleteSync(recursive: true);
}
