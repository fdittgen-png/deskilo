// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2600 C2 — which test files the quality workflow requires, and which
// shard runs each of them.
//
// The required set is a deterministic walk of `test/` for `*_test.dart`
// — what a bare `flutter test` selects — never a directory list written
// in the workflow. A new root directory, a new feature folder or a stray
// file therefore lands in a shard by RULE and cannot be left unrun; and
// the plan is proved against the walk (ShardPlan.problems) before any
// result is trusted.
//
//   gate   everything outside test/features/ (lint, tool, i18n, a11y, ux,
//          perf, app, core, helpers holding tests, anything new)
//   money  test/features/money/ and test/features/workspace/
//   rest   the other feature folders
//
// Each file belongs to exactly one shard, and a shard is a list of single
// files: selecting a directory and one of its files would run the file
// twice.
import 'dart:io';

import 'shards.dart';

const gateShard = 'gate';
const moneyShard = 'money';
const restShard = 'rest';

/// Every `*_test.dart` under [root]/test, repository-relative, sorted.
List<String> requiredTestFiles({String root = '.'}) {
  final base = Directory('$root/test');
  if (!base.existsSync()) return const [];
  final out = <String>[];
  for (final e in base.listSync(recursive: true, followLinks: false)) {
    if (e is! File || !e.path.endsWith('_test.dart')) continue;
    var rel = e.path.substring(root.length);
    while (rel.startsWith('/')) {
      rel = rel.substring(1);
    }
    out.add(rel);
  }
  return out..sort();
}

/// The shard that runs [path] under the default plan.
String shardOf(String path) {
  if (!path.startsWith('test/features/')) return gateShard;
  if (path.startsWith('test/features/money/') ||
      path.startsWith('test/features/workspace/')) {
    return moneyShard;
  }
  return restShard;
}

/// The default plan's shards over [files]. Each must be non-empty: an
/// empty shard is not declared, so it fails closed instead of passing.
List<ShardSpec> defaultShards(Iterable<String> files) {
  final by = <String, List<String>>{
    gateShard: [],
    moneyShard: [],
    restShard: [],
  };
  for (final f in files) {
    by[shardOf(f)]!.add(f);
  }
  return [for (final e in by.entries) ShardSpec(id: e.key, files: e.value)];
}

/// Names the shell would split or reinterpret; `flutter test` receives
/// the list as separate arguments.
List<String> unsafeNames(Iterable<String> files) => [
  for (final f in files)
    if (RegExp(r'''[\s'"\\$`;&|<>*?(){}\[\]!#~]''').hasMatch(f)) f,
];
