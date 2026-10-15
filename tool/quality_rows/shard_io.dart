// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2600 C1 — where the shard artifacts are read from.
//
// The aggregate job downloads one artifact per shard (named so that the
// `quality-*` pattern of the report job never flattens them together):
//
//   <dir>/testshard-<id>/envelope.json   who ran what, how it ended
//   <dir>/testshard-<id>/tests.jsonl     the reporter stream, as written
//   <dir>/testshard-<id>/lcov.info       the shard's own coverage
//
// A file that is absent is passed on as absent (null): `readShard` turns
// that into a violation, so a missing artifact can never read as success.
import 'dart:convert';
import 'dart:io';

import 'shards.dart';

const shardArtifactPrefix = 'testshard-';

String? _read(String path) {
  final f = File(path);
  return f.existsSync() ? f.readAsStringSync() : null;
}

ShardPlan readPlan(String path) {
  final text = _read(path);
  if (text == null) throw FormatException('the plan $path does not exist');
  final json = jsonDecode(text);
  if (json is! Map<String, dynamic>) {
    throw const FormatException('the plan is not an object');
  }
  return ShardPlan.fromJson(json);
}

/// Everything a shard left in [dir], read and validated alone. Never
/// throws: an unreadable envelope is the same as none.
ShardResult readShardDir(ShardPlan plan, ShardSpec spec, String dir) {
  final base = '$dir/$shardArtifactPrefix${spec.id}';
  ShardEnvelope? envelope;
  String? invalid;
  final text = _read('$base/envelope.json');
  if (text != null) {
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('the envelope is not an object');
      }
      envelope = ShardEnvelope.fromJson(json);
    } on FormatException catch (e) {
      invalid = e.message;
    }
  }
  final result = readShard(
    plan: plan,
    expected: spec,
    envelope: envelope,
    stream: _read('$base/tests.jsonl'),
    lcov: _read('$base/lcov.info'),
  );
  if (invalid != null) result.violations.add('the envelope is unreadable: $invalid');
  return result;
}

/// The whole plan read from [dir].
MergedRun readMerged(ShardPlan plan, String dir) => mergeValidatedShards(plan, {
      for (final s in plan.shards) s.id: readShardDir(plan, s, dir),
    });
