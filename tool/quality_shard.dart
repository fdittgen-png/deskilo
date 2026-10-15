// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2600 C2 — the producer side of the sharded quality run. One tool, four
// commands, so that the shard jobs and the aggregate job derive the same
// selection from the same tree instead of trusting a list typed twice.
//
//   select      --shard <id> [--out files.txt]
//       The files this shard runs, one per line. Fails when the plan does
//       not cover test/**/*_test.dart exactly once, or a name is unsafe.
//   envelope    --shard <id> --exit-code <n> --stream <jsonl> [--lcov <f>]
//               --candidate <sha> --run-id <id> --run-attempt <n>
//               --profile <text> --sdk <text> --out <json>
//       The record a shard job leaves beside its stream.
//   plan        --candidate <sha> --run-id <id> --run-attempt <n> --out <json>
//       The aggregate job's expectation, re-derived from the tree.
//   merge-lcov  --plan <json> --shards <dir> --out <lcov.info>
//       The validated shards' coverage as one report. Fails closed on any
//       contract violation or an LCOV that does not match its envelope.
import 'dart:convert';
import 'dart:io';

import 'quality_rows/lcov_merge.dart';
import 'quality_rows/selection.dart';
import 'quality_rows/shard_io.dart';
import 'quality_rows/shards.dart';

void main(List<String> args) => exitCode = run(args);

int run(List<String> args) {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final command = args.isEmpty ? '' : args.first;
  switch (command) {
    case 'select':
      return _select(option);
    case 'envelope':
      return _envelope(option);
    case 'plan':
      return _plan(option);
    case 'merge-lcov':
      return _mergeLcov(option);
    default:
      stderr.writeln(
        'usage: dart run tool/quality_shard.dart '
        '(select | envelope | plan | merge-lcov) …  (see the file header)',
      );
      return 2;
  }
}

/// The tree's plan, or null after printing why it cannot be one.
List<ShardSpec>? _specs() {
  final files = requiredTestFiles();
  final specs = defaultShards(files);
  final plan = ShardPlan(
    candidate: 'x',
    runId: 'x',
    runAttempt: 'x',
    shards: specs,
  );
  final problems = [
    ...plan.problems(required: files.toSet()),
    for (final f in unsafeNames(files))
      '$f has a character a shell would reinterpret',
  ];
  if (files.isEmpty) problems.add('test/ holds no test file');
  for (final p in problems) {
    stderr.writeln('::error::test selection: $p');
  }
  return problems.isEmpty ? specs : null;
}

int _select(String? Function(String) option) {
  final id = option('shard');
  if (id == null) return _usage('select needs --shard');
  final specs = _specs();
  if (specs == null) return 1;
  final spec = specs.where((s) => s.id == id).firstOrNull;
  if (spec == null) {
    stderr.writeln('::error::no shard named $id');
    return 1;
  }
  final text = spec.files.map((f) => '$f\n').join();
  final out = option('out');
  if (out == null) {
    stdout.write(text);
  } else {
    File(out)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
    stdout.writeln('${spec.id}: ${spec.files.length} files');
  }
  return 0;
}

int _envelope(String? Function(String) option) {
  final needed = {
    for (final k in const [
      'shard',
      'exit-code',
      'stream',
      'candidate',
      'run-id',
      'run-attempt',
      'profile',
      'sdk',
      'out',
    ])
      k: option(k),
  };
  final missing = [
    for (final e in needed.entries)
      if (e.value == null) e.key,
  ];
  final exit = int.tryParse(needed['exit-code'] ?? '');
  if (missing.isNotEmpty || exit == null) {
    return _usage(
      'envelope needs ${missing.isEmpty ? 'an integer --exit-code' : missing.map((k) => '--$k').join(', ')}',
    );
  }
  final specs = _specs();
  if (specs == null) return 1;
  final spec = specs.where((s) => s.id == needed['shard']).firstOrNull;
  if (spec == null) {
    stderr.writeln('::error::no shard named ${needed['shard']}');
    return 1;
  }
  String? read(String? path) {
    if (path == null) return null;
    final f = File(path);
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  final stream = read(needed['stream']);
  final lcov = read(option('lcov'));
  final envelope = ShardEnvelope(
    schema: shardSchema,
    candidate: needed['candidate']!,
    runId: needed['run-id']!,
    runAttempt: needed['run-attempt']!,
    shard: spec.id,
    profile: needed['profile']!,
    sdk: needed['sdk']!,
    selectionDigest: spec.digest,
    files: spec.files,
    exitCode: exit,
    completed: true,
    emptySelection: spec.files.isEmpty,
    streamSha256: stream == null ? null : sha256Hex(stream),
    lcovSha256: lcov == null ? null : sha256Hex(lcov),
  );
  File(needed['out']!)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(envelope.toJson())}\n',
    );
  stdout.writeln(
    '${spec.id}: exit $exit, ${spec.files.length} files, '
    'stream ${stream == null ? 'MISSING' : 'recorded'}, '
    'lcov ${lcov == null ? 'MISSING' : 'recorded'}',
  );
  return 0;
}

int _plan(String? Function(String) option) {
  final candidate = option('candidate');
  final runId = option('run-id');
  final attempt = option('run-attempt');
  final out = option('out');
  if (candidate == null || runId == null || attempt == null || out == null) {
    return _usage('plan needs --candidate, --run-id, --run-attempt and --out');
  }
  final specs = _specs();
  if (specs == null) return 1;
  final plan = ShardPlan(
    candidate: candidate,
    runId: runId,
    runAttempt: attempt,
    shards: specs,
  );
  File(out)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(plan.toJson())}\n',
    );
  stdout.writeln(
    plan.shards.map((s) => '${s.id}: ${s.files.length} files').join('; '),
  );
  return 0;
}

int _mergeLcov(String? Function(String) option) {
  final planPath = option('plan');
  final dir = option('shards');
  final out = option('out');
  if (planPath == null || dir == null || out == null) {
    return _usage('merge-lcov needs --plan, --shards and --out');
  }
  final ShardPlan plan;
  try {
    plan = readPlan(planPath);
  } on FormatException catch (e) {
    stderr.writeln('::error::shard plan: ${e.message}');
    return 1;
  }
  final reports = <String>[];
  var bad = false;
  for (final spec in plan.shards) {
    final result = readShardDir(plan, spec, dir);
    for (final v in result.violations) {
      stderr.writeln('::error::[${spec.id}] $v');
      bad = true;
    }
    if (spec.files.isEmpty) continue;
    final f = File('$dir/$shardArtifactPrefix${spec.id}/lcov.info');
    if (!result.lcovOk || !f.existsSync()) {
      stderr.writeln('::error::[${spec.id}] has no valid LCOV to merge');
      bad = true;
      continue;
    }
    reports.add(f.readAsStringSync());
  }
  if (bad) return 1;
  try {
    final merged = mergeLcov(reports, root: Directory.current.path);
    File(out)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(merged);
    stdout.writeln('merged ${reports.length} LCOV reports into $out');
    return 0;
  } on LcovFormatException catch (e) {
    stderr.writeln('::error::LCOV merge: ${e.message}');
    return 1;
  }
}

int _usage(String message) {
  stderr.writeln('quality_shard: $message');
  return 2;
}
