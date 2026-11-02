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
//   gate       everything outside test/features/ except test/core/, test/app/
//              and test/a11y/ (lint, tool, i18n, ux, perf and anything a new
//              root folder adds)
//   money      test/features/money/ files named a..m, and reservations/
//   money2     test/features/money/ files named n..z, and me/ and auth/
//   workspace  test/features/workspace/
//   rest       the other feature folders (a new one lands here)
//   core       test/core/, test/app/, test/a11y/ and test/features/profile/
//
// #3166 — six shards, split by measured file times (run 41369658767: about
// 10,300 file-seconds; the shard wall clock is about that divided by 2.8):
// each non-gate shard carries about 1,800-2,000 file-seconds, so about 11-12
// minutes of tests and 13-14 with setup, against 17-18 minutes of tests in
// the earlier four. The gate job also carries about 400 s of analysis and
// codegen, so it keeps the fewest tests. money is the one folder that is
// split inside: by the first character of the file's path under it, which a
// new file falls on by rule.
//
// Each file belongs to exactly one shard, and a shard is a list of single
// files: selecting a directory and one of its files would run the file
// twice.
import 'dart:io';

import 'shards.dart';

const gateShard = 'gate';
const moneyShard = 'money';
const money2Shard = 'money2';
const restShard = 'rest';
const workspaceShard = 'workspace';
const coreShard = 'core';

/// #3166 — the folders each shard runs, by measured weight.
const _moneyRoot = 'test/features/money/';

/// The first path under [_moneyRoot] that belongs to money2: names before
/// it run in money, names from it on in money2.
const _moneySplit = 'n';
const _moneyFolders = ['test/features/reservations/'];
const _money2Folders = ['test/features/me/', 'test/features/auth/'];
const _workspaceFolders = ['test/features/workspace/'];
const _coreRoots = [
  'test/core/',
  'test/app/',
  'test/a11y/',
  'test/features/profile/',
];

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
  bool under(List<String> roots) => roots.any(path.startsWith);
  if (under(_coreRoots)) return coreShard;
  if (path.startsWith(_moneyRoot)) {
    return path.substring(_moneyRoot.length).compareTo(_moneySplit) < 0
        ? moneyShard
        : money2Shard;
  }
  if (!path.startsWith('test/features/')) return gateShard;
  if (under(_moneyFolders)) return moneyShard;
  if (under(_money2Folders)) return money2Shard;
  if (under(_workspaceFolders)) return workspaceShard;
  return restShard;
}

/// The default plan's shards over [files]. Each must be non-empty: an
/// empty shard is not declared, so it fails closed instead of passing.
List<ShardSpec> defaultShards(Iterable<String> files) {
  final by = <String, List<String>>{
    gateShard: [],
    moneyShard: [],
    money2Shard: [],
    workspaceShard: [],
    restShard: [],
    coreShard: [],
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
