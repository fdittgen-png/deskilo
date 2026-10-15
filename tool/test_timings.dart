// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 B — the hotspot view of the suite run that already happened.
//
// Usage (quality.yml runs it after the one suite run):
//   dart run tool/test_timings.dart --events report/tests.jsonl \
//     --candidate <sha> --profile <name> --runtime <flutter version> \
//     --out report/test-timings.md --raw-out report/test-events.jsonl
//
// Sharded (#2600): `--plan plan.json --shards <dir>` reads one stream per
// shard, each on its own clock (tool/test_timings/timings.dart).
//
// Advisory: it reports, it never decides a verdict. Exit 2 only when it
// was called wrongly.

import 'dart:io';

import 'quality_rows/shard_io.dart';
import 'quality_rows/shards.dart';
import 'test_timings/timings.dart';

void main(List<String> args) => exitCode = run(args);

int run(List<String> args) {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final events = option('events');
  final out = option('out');
  final planPath = option('plan');
  final shardsDir = option('shards');
  if ((events == null && (planPath == null || shardsDir == null)) ||
      out == null) {
    stderr.writeln(
      'usage: dart run tool/test_timings.dart '
      '(--events <jsonl> | --plan <json> --shards <dir>) '
      '--out <md> [--raw-out <jsonl>] [--candidate <sha>] '
      '[--profile <name>] [--runtime <version>]',
    );
    return 2;
  }
  if (planPath != null && shardsDir != null) {
    final ShardPlan plan;
    try {
      plan = readPlan(planPath);
    } on FormatException catch (e) {
      stderr.writeln('shard plan: ${e.message}');
      return 2;
    }
    final sharded = ShardedTimings({
      for (final s in plan.shards)
        s.id: readTimings(_streamOf('$shardsDir/$shardArtifactPrefix${s.id}')),
    });
    File(out)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        renderShardedTimings(
          sharded,
          candidate: option('candidate') ?? plan.candidate,
          profile: option('profile') ?? 'unknown',
          runtime: option('runtime') ?? 'unknown',
        ),
      );
    final raw = option('raw-out');
    if (raw != null) {
      File(raw)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('${sharded.kept.join('\n')}\n');
    }
    stdout.writeln(
      '${sharded.shards.length} shards: critical path ${sharded.criticalPath} ms, '
      'summed work ${sharded.summedWork} ms',
    );
    return 0;
  }
  final file = File(events!);
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

String _streamOf(String dir) {
  final f = File('$dir/tests.jsonl');
  return f.existsSync() ? f.readAsStringSync() : '';
}
