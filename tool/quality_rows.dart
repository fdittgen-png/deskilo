// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C1 — derives the code job's discipline rows from ONE test run.
//
//   dart run tool/quality_rows.dart --events report/tests.jsonl \
//       --exit-code 0 --manifest .github/quality-manifest.psv \
//       --out report/tests.psv
//
// Sharded (#2600): the same rows from several validated runs.
//
//   dart run tool/quality_rows.dart --plan plan.json --shards shards/ \
//       --manifest .github/quality-manifest.psv --out report/tests.psv
//
// Each shard is read alone against the selection the plan promised for it;
// only validated results are combined (tool/quality_rows/shards.dart).
//
// Exit 1 when the stream breaks the reporting contract (cut short, empty,
// an event it does not understand, an error outside a test): the rows
// are still written, all red, so the report says WHY and the gate is red
// for a reporting failure rather than green by accident.
import 'dart:io';

import 'quality_rows/rows.dart';
import 'quality_rows/shard_io.dart';
import 'quality_rows/shards.dart';

// Dart ignores what `main` returns: `return 1` exited 0, so the rows
// step was green over a broken stream (the rows themselves were red).
void main(List<String> args) => exitCode = run(args);

int run(List<String> args) {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final events = option('events');
  final planPath = option('plan');
  final shardsDir = option('shards');
  final manifestPath = option('manifest');
  final out = option('out');
  final exitCode = int.tryParse(option('exit-code') ?? '');
  final sharded = planPath != null && shardsDir != null;
  if (manifestPath == null ||
      out == null ||
      (!sharded && (events == null || exitCode == null))) {
    stderr.writeln('usage: dart run tool/quality_rows.dart '
        '(--events <jsonl> --exit-code <n> | --plan <json> --shards <dir>) '
        '--manifest <psv> --out <psv>');
    return 2;
  }
  final manifest = parseManifest(File(manifestPath).readAsStringSync());
  final RunResult run;
  final Row suite;
  if (sharded) {
    final ShardPlan plan;
    try {
      plan = readPlan(planPath);
    } on FormatException catch (e) {
      stderr.writeln('::error::shard plan: ${e.message}');
      File(out)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('Tests|failure|the shard plan is unreadable: ${e.message}\n');
      return 1;
    }
    final merged = readMerged(plan, shardsDir);
    run = merged.run;
    final single = suiteRow(run, exitCode: merged.exitCode);
    suite = Row(single.name, single.outcome, '${single.evidence} [${merged.summary}]');
  } else {
    final stream = File(events!).existsSync() ? File(events).readAsStringSync() : '';
    run = readRun(stream);
    suite = suiteRow(run, exitCode: exitCode!);
  }
  final rows = [suite, ...deriveRows(manifest, run, job: 'code')];
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
