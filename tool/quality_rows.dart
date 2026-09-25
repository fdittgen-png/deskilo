// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C1 — derives the code job's discipline rows from ONE test run.
//
//   dart run tool/quality_rows.dart --events report/tests.jsonl \
//       --exit-code 0 --manifest .github/quality-manifest.psv \
//       --out report/tests.psv
//
// Exit 1 when the stream breaks the reporting contract (cut short, empty,
// an event it does not understand, an error outside a test): the rows
// are still written, all red, so the report says WHY and the gate is red
// for a reporting failure rather than green by accident.
import 'dart:io';

import 'quality_rows/rows.dart';

// Dart ignores what `main` returns: `return 1` exited 0, so the rows
// step was green over a broken stream (the rows themselves were red).
void main(List<String> args) => exitCode = run(args);

int run(List<String> args) {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final events = option('events');
  final manifestPath = option('manifest');
  final out = option('out');
  final exitCode = int.tryParse(option('exit-code') ?? '');
  if (events == null || manifestPath == null || out == null || exitCode == null) {
    stderr.writeln('usage: dart run tool/quality_rows.dart --events <jsonl> '
        '--exit-code <n> --manifest <psv> --out <psv>');
    return 2;
  }
  final manifest = parseManifest(File(manifestPath).readAsStringSync());
  final stream = File(events).existsSync() ? File(events).readAsStringSync() : '';
  final run = readRun(stream);
  final rows = [
    suiteRow(run, exitCode: exitCode),
    ...deriveRows(manifest, run, job: 'code'),
  ];
  File(out)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('${rows.map((r) => r.psv).join('\n')}\n');
  for (final row in rows) {
    stdout.writeln(row.psv);
  }
  if (run.violations.isNotEmpty) {
    for (final v in run.violations) {
      stderr.writeln('::error::test stream: $v');
    }
    return 1;
  }
  return 0;
}
