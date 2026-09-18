// SPDX-License-Identifier: 0BSD
//
// #1446 C2 — writes the change classification the quality workflow acts
// on: `discipline|required|not_applicable|reason|version`, one line each,
// plus one GitHub output per discipline.
//
//   git diff --name-status -z "$BASE" "$HEAD" > changes.nul
//   dart run tool/ci_classify.dart --event pull_request \
//       --changes changes.nul --out report/classification.txt
//
// Pass `--no-base` when the base commit could not be resolved: the
// classifier then selects everything, which is the only honest answer.
import 'dart:io';

import 'ci_classify/classify.dart';

int main(List<String> args) {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final event = option('event') ?? 'unknown';
  final changes = option('changes');
  final out = option('out');
  if (out == null) {
    stderr.writeln('usage: dart run tool/ci_classify.dart --event <event> '
        '[--changes <name-status.nul>] [--no-base] --out <txt>');
    return 2;
  }
  final baseKnown = !args.contains('--no-base');
  final paths = changes != null && File(changes).existsSync()
      ? pathsFromNameStatus(File(changes).readAsStringSync())
      : const <String>[];
  final verdicts = classify(
    ChangeSet(paths: paths, baseKnown: baseKnown, event: event),
  );
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
