// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1632 — the MCP coverage gate. `contracts/mcp/coverage.json` maps every
// operation the contract hands to a handler to the executable tests that
// prove it: a positive case, an authorisation denial and, for anything
// that changes state, a state-change regression. The gate refuses:
//
//   * an implemented operation the map does not name, or a name the
//     contract does not implement (a new tool is never silently covered);
//   * a missing category, a reference that does not exist, or one that
//     never mentions the operation it claims to cover;
//   * a map written against another contract: the recorded sha256 of
//     `contracts/mcp/operations.json` must be the current one, so a new
//     tool or output field forces a coverage review;
//   * with `--pgtap`: a pgTAP report that is empty, from another source
//     commit, that lacks a required file, or where a required file did
//     not end `ok` (failed, dubious, skipped, planned nothing).
//
// A list of test names is not evidence; the report of their execution is.
// Pure dart:io plus package:crypto, no live backend.
import 'dart:convert';

import 'package:crypto/crypto.dart';

const coveragePath = 'contracts/mcp/coverage.json';
const contractPath = 'contracts/mcp/operations.json';

const _categories = ['positive', 'denial', 'state'];

/// Where an executable test may live.
final _testRef = RegExp(
  r'^(supabase/tests/database/[0-9]+_[a-z0-9_]+\.sql'
  r'|test/.+_test\.dart'
  r'|supabase/functions/[a-z0-9-]+/[a-z0-9_]+_test\.ts'
  r'|scripts/[a-z0-9_]+\.sh)$',
);

String contractFingerprint(List<int> bytes) => sha256.convert(bytes).toString();

/// The operations the contract hands to a handler, with their mutation.
Map<String, String> implementedOperations(Map<String, dynamic> contract) => {
  for (final o in (contract['operations'] as List).cast<Map<String, dynamic>>())
    if (o['handler'] == true) o['id'] as String: o['mutation'] as String,
};

/// Every reason the coverage map may not stand. Empty means it holds.
///
/// [read] answers a repository-relative path's text, or null when absent.
List<String> validateCoverage(
  Map<String, dynamic> coverage,
  Map<String, dynamic> contract,
  String contractSha,
  String? Function(String path) read,
) {
  final problems = <String>[];
  if (coverage['contract'] != 'deskilo.mcp.coverage' ||
      coverage['version'] != 1) {
    problems.add('coverage.json is not a deskilo.mcp.coverage version 1 map');
  }
  if (coverage['contract_sha256'] != contractSha) {
    problems.add(
      'coverage.json was reviewed against another operations.json '
      '(recorded ${coverage['contract_sha256']}, current $contractSha): '
      'review every new tool and field, then record the new fingerprint',
    );
  }
  for (final key in ['catalogue_tests', 'journeys']) {
    final refs = coverage[key];
    if (refs is! List || refs.isEmpty) {
      problems.add('$key must name at least one test');
      continue;
    }
    for (final ref in refs) {
      if (ref is! String || !_testRef.hasMatch(ref) || read(ref) == null) {
        problems.add('$key: `$ref` is not an existing test file');
      }
    }
  }
  final implemented = implementedOperations(contract);
  final mapped = coverage['operations'];
  if (mapped is! Map) return [...problems, 'operations must be an object'];
  for (final op in implemented.keys.where((o) => !mapped.containsKey(o))) {
    problems.add('$op is implemented but has no coverage entry');
  }
  for (final op in mapped.keys.where((o) => !implemented.containsKey(o))) {
    problems.add('$op is covered but the contract implements no such tool');
  }
  final mention = <String, RegExp>{};
  for (final entry in mapped.entries) {
    final op = entry.key as String;
    final mutation = implemented[op];
    if (mutation == null) continue;
    final e = entry.value;
    if (e is! Map) {
      problems.add('$op: entry must be an object');
      continue;
    }
    for (final k in e.keys.where((k) => !_categories.contains(k))) {
      problems.add('$op: unknown category `$k`');
    }
    final needed = ['positive', 'denial', if (mutation != 'read') 'state'];
    for (final category in needed) {
      final refs = e[category];
      if (refs is! List || refs.isEmpty) {
        problems.add('$op: no $category test');
        continue;
      }
      for (final ref in refs) {
        final text = ref is String && _testRef.hasMatch(ref) ? read(ref) : null;
        if (text == null) {
          problems.add('$op: $category `$ref` is not an existing test file');
          continue;
        }
        final named = mention.putIfAbsent(
          op,
          () => RegExp("['\"](deskilo_)?$op['\"]|deskilo_$op\\b"),
        );
        if (!named.hasMatch(text)) {
          problems.add('$op: $category `$ref` never names $op');
        }
      }
    }
  }
  return problems;
}

/// Every pgTAP file the map requires to have run.
Set<String> requiredPgtap(Map<String, dynamic> coverage) => {
  for (final ref in _allRefs(coverage))
    if (ref.startsWith('supabase/tests/database/')) ref.split('/').last,
};

Iterable<String> _allRefs(Map<String, dynamic> coverage) sync* {
  for (final key in ['catalogue_tests', 'journeys']) {
    yield* ((coverage[key] as List?) ?? const []).whereType<String>();
  }
  final ops = coverage['operations'];
  if (ops is! Map) return;
  for (final e in ops.values) {
    if (e is! Map) continue;
    for (final refs in e.values) {
      if (refs is List) yield* refs.whereType<String>();
    }
  }
}

/// What a `supabase test db` (pg_prove) report says about each file:
/// its status word, `ok` only when the file passed.
Map<String, String> readPgtapReport(String report) {
  final status = <String, String>{};
  final file = RegExp(r'([0-9]+_[a-z0-9_]+\.sql) \.+ ?(.*)$');
  String? open;
  for (final raw in const LineSplitter().convert(report)) {
    final line = raw.trimRight();
    final m = file.firstMatch(line);
    if (m != null) {
      open = m.group(1)!;
      final rest = m.group(2)!.trim();
      status[open] = rest;
      if (rest.isNotEmpty) open = null;
      continue;
    }
    // pg_prove prints diagnostics first and the verdict after them.
    if (open != null && !line.startsWith('#') && line.trim().isNotEmpty) {
      status[open] = line.trim();
      open = null;
    }
  }
  return status;
}

bool _passed(String status) =>
    RegExp(r'^ok\b').hasMatch(status) && !status.toLowerCase().contains('skip');

/// Every reason [report] is not evidence for [coverage] at [sha].
List<String> checkPgtapEvidence(
  Map<String, dynamic> coverage,
  String? report,
  String sha,
) {
  if (report == null || report.trim().isEmpty) {
    return ['the pgTAP report is missing or empty: nothing was executed'];
  }
  final problems = <String>[];
  final source = RegExp(
    r'^# source ([0-9a-f]{7,40})$',
    multiLine: true,
  ).firstMatch(report)?.group(1);
  if (source == null) {
    problems.add('the pgTAP report names no source commit');
  } else if (source != sha) {
    problems.add('the pgTAP report is for $source, not $sha: stale evidence');
  }
  final status = readPgtapReport(report);
  if (status.isEmpty) problems.add('the pgTAP report ran no file');
  for (final f in requiredPgtap(coverage).toList()..sort()) {
    final s = status[f];
    if (s == null) {
      problems.add('$f never ran');
    } else if (!_passed(s)) {
      problems.add('$f did not pass: $s');
    }
  }
  return problems;
}
