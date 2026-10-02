// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 B — the hotspot view of the suite run that already happened.
//
// Usage (quality.yml runs it after the one suite run):
//   dart run tool/test_timings.dart --events report/tests.jsonl \
//     --candidate <sha> --profile <name> --runtime <flutter version> \
//     --out report/test-timings.md --raw-out report/test-events.jsonl
//
// Advisory: it reports, it never decides a verdict. Exit 2 only when it
// was called wrongly.

import 'dart:io';

import 'test_timings/timings.dart';

void main(List<String> args) => exitCode = run(args);

int run(List<String> args) {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final events = option('events');
  final out = option('out');
  if (events == null || out == null) {
    stderr.writeln(
      'usage: dart run tool/test_timings.dart --events <jsonl> '
      '--out <md> [--raw-out <jsonl>] [--candidate <sha>] '
      '[--profile <name>] [--runtime <version>]',
    );
    return 2;
  }
  final file = File(events);
  final timings = readTimings(file.existsSync() ? file.readAsStringSync() : '');
  File(out)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      renderTimings(
        timings,
        candidate: option('candidate') ?? 'unknown',
        profile: option('profile') ?? 'unknown',
        runtime: option('runtime') ?? 'unknown',
      ),
    );
  final raw = option('raw-out');
  if (raw != null) {
    File(raw)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('${timings.kept.join('\n')}\n');
  }
  stdout.writeln(
    '${timings.end.name}: ${timings.files.length} files, '
    'wall ${timings.wall} ms, overlap ${timings.overlap.toStringAsFixed(1)}×',
  );
  return 0;
}
