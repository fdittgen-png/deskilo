// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C2 — writes the change classification the quality and web
// workflows act on: `discipline|required|not_applicable|reason|version`,
// one line each, plus one GitHub output per discipline.
//
//   git diff --name-status -z "$BASE" "$HEAD" > changes.nul
//   dart run tool/ci_classify.dart --event pull_request \
//       --changes changes.nul --out report/classification.txt
//
// Pass `--no-base` when the base commit could not be resolved, and
// `--diff-problem "<why>"` when git could not write the change list: the
// classifier then selects everything, which is the only honest answer.
// A change list named but absent, or one whose records are cut short,
// is the same case and needs no flag — the parser reports it.
//
// `scripts/ci_classify.sh` is the invocation both workflows share.
import 'dart:io';

import 'ci_classify/classify.dart';

// Dart ignores the value `main` returns: `int main() => 2` exits 0. The
// exit code is set explicitly, or a usage error reads as a verdict.
void main(List<String> args) => exitCode = run(args);

int run(List<String> args) {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final event = option('event') ?? 'unknown';
  final changes = option('changes');
  final out = option('out');
  if (out == null) {
    stderr.writeln('usage: dart run tool/ci_classify.dart --event <event> '
        '[--changes <name-status.nul>] [--no-base] '
        '[--diff-problem <why>] --out <txt>');
    return 2;
  }
  final baseKnown = !args.contains('--no-base');
  var problem = option('diff-problem');
  var paths = const <String>[];
  if (changes != null && problem == null && baseKnown) {
    final file = File(changes);
    if (!file.existsSync()) {
      problem = 'the change list $changes was not written';
    } else {
      final parsed = pathsFromNameStatus(file.readAsStringSync());
      paths = parsed.paths;
      problem = parsed.problem;
    }
  }
  final verdicts = classify(ChangeSet(
    paths: paths,
    baseKnown: baseKnown,
    event: event,
    problem: problem,
  ));
  File(out)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('${verdicts.map((v) => v.psv).join('\n')}\n');
  final github = Platform.environment['GITHUB_OUTPUT'];
  for (final v in verdicts) {
    stdout.writeln(v.psv);
    if (github != null) {
      File(github).writeAsStringSync(
        '${v.discipline}=${v.required ? 'required' : 'not_applicable'}\n',
        mode: FileMode.append,
      );
    }
  }
  return 0;
}
