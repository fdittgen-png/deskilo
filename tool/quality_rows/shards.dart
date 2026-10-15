// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2600 C1 — several test runs, one verdict, no shared trust.
//
// `readRun` (rows.dart) reads ONE `flutter test` reporter stream: one
// `start`, one `done`, run-local numeric ids. Several runs concatenated
// into it would let a later run's `done` hide an earlier run that was cut
// short, and would mix their ids. So each shard is read ALONE against the
// selection the plan promised for it, and only the typed, already
// validated results are combined:
//
//   readShard            envelope + stream + LCOV -> ShardResult (violations)
//   mergeValidatedShards plan + results           -> MergedRun (a RunResult
//                        the existing row functions consume, plus
//                        per-shard diagnostics)
//
// A contract violation anywhere makes the whole aggregate unreadable, which
// the row functions already turn into red rows. A nonzero exit or a failed
// test is a RESULT, not a violation: the stream is still read so the rows
// can name the discipline that regressed.
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'rows.dart';

/// Version of the envelope and plan JSON.
const shardSchema = 1;

String sha256Hex(String text) => sha256.convert(utf8.encode(text)).toString();

/// The identity of a selection: the sorted repository-relative files,
/// one per line. Order of listing never changes it; content always does.
String selectionDigest(Iterable<String> files) {
  final sorted = [...files]..sort();
  return sha256Hex(sorted.map((f) => '$f\n').join());
}

/// What one shard is promised to run.
class ShardSpec {
  ShardSpec({
    required this.id,
    required List<String> files,
    this.emptyAllowed = false,
    this.coverage = true,
  }) : files = List.unmodifiable([...files]..sort());

  final String id;

  /// Single test files, repository-relative, sorted. Never a directory:
  /// selecting a directory and one of its files would run the file twice.
  final List<String> files;

  /// An empty selection is legitimate only when the plan says so.
  final bool emptyAllowed;

  /// The shard must deliver an LCOV file.
  final bool coverage;

  String get digest => selectionDigest(files);

  Map<String, Object?> toJson() => {
    'id': id,
    'files': files,
    'digest': digest,
    'emptyAllowed': emptyAllowed,
    'coverage': coverage,
  };

  factory ShardSpec.fromJson(Map<String, dynamic> j) {
    final spec = ShardSpec(
      id: _str(j, 'id'),
      files: _strings(j, 'files'),
      emptyAllowed: j['emptyAllowed'] == true,
      coverage: j['coverage'] != false,
    );
    if (j['digest'] != spec.digest) {
      throw FormatException(
        'shard ${spec.id}: the digest does not match its files',
      );
    }
    return spec;
  }
}

/// The whole run's promise: which candidate, which run, which shards.
class ShardPlan {
  ShardPlan({
    required this.candidate,
    required this.runId,
    required this.runAttempt,
    required this.shards,
  });

  final String candidate;
  final String runId;
  final String runAttempt;
  final List<ShardSpec> shards;

  Map<String, Object?> toJson() => {
    'schema': shardSchema,
    'candidate': candidate,
    'runId': runId,
    'runAttempt': runAttempt,
    'shards': [for (final s in shards) s.toJson()],
  };

  factory ShardPlan.fromJson(Map<String, dynamic> j) {
    if (j['schema'] != shardSchema) {
      throw FormatException('plan schema ${j['schema']} is not $shardSchema');
    }
    final shards = j['shards'];
    if (shards is! List) throw const FormatException('plan has no shards list');
    return ShardPlan(
      candidate: _str(j, 'candidate'),
      runId: _str(j, 'runId'),
      runAttempt: _str(j, 'runAttempt'),
      shards: [
        for (final s in shards)
          ShardSpec.fromJson(
            s is Map<String, dynamic>
                ? s
                : throw const FormatException('shard is not an object'),
          ),
      ],
    );
  }

  /// What is wrong with the selection itself: a directory or a non-test
  /// entry, a file listed twice or by two shards, an empty selection that
  /// was not declared, and — given the [required] files — a required file
  /// no shard runs or a selected file nobody required.
  List<String> problems({Set<String>? required}) {
    final out = <String>[];
    final owner = <String, String>{};
    final ids = <String>{};
    for (final s in shards) {
      if (!ids.add(s.id)) out.add('shard ${s.id} is declared twice');
      if (s.files.isEmpty && !s.emptyAllowed) {
        out.add(
          'shard ${s.id} has an empty selection that the plan did not declare',
        );
      }
      final seen = <String>{};
      for (final f in s.files) {
        if (!f.endsWith('_test.dart') || f.endsWith('/')) {
          out.add('$f is not a single test file (shard ${s.id})');
          continue;
        }
        if (!seen.add(f)) out.add('shard ${s.id} lists $f twice');
        final other = owner[f];
        if (other != null && other != s.id) {
          out.add('$f is selected by both $other and ${s.id}');
        }
        owner.putIfAbsent(f, () => s.id);
      }
    }
    if (required != null) {
      for (final f in required.toList()..sort()) {
        if (!owner.containsKey(f)) out.add('$f is selected by no shard');
      }
      for (final f in owner.keys.toList()..sort()) {
        if (!required.contains(f)) out.add('$f is not a required test file');
      }
    }
    return out;
  }
}

/// What a shard job writes beside its stream: who it was, what it was
/// told to run, how the process ended, and hashes of what it produced.
class ShardEnvelope {
  ShardEnvelope({
    required this.schema,
    required this.candidate,
    required this.runId,
    required this.runAttempt,
    required this.shard,
    required this.profile,
    required this.sdk,
    required this.selectionDigest,
    required this.files,
    required this.exitCode,
    required this.completed,
    required this.emptySelection,
    required this.streamSha256,
    required this.lcovSha256,
  });

  final int schema;
  final String candidate;
  final String runId;
  final String runAttempt;
  final String shard;
  final String profile;
  final String sdk;
  final String selectionDigest;
  final List<String> files;

  /// The test process's own exit code.
  final int exitCode;

  /// The envelope writer reached its end: the job did not die before it.
  final bool completed;

  /// The shard declares that it had nothing to run.
  final bool emptySelection;
  final String? streamSha256;
  final String? lcovSha256;

  Map<String, Object?> toJson() => {
    'schema': schema,
    'candidate': candidate,
    'runId': runId,
    'runAttempt': runAttempt,
    'shard': shard,
    'profile': profile,
    'sdk': sdk,
    'selectionDigest': selectionDigest,
    'files': files,
    'exitCode': exitCode,
    'completed': completed,
    'emptySelection': emptySelection,
    'streamSha256': streamSha256,
    'lcovSha256': lcovSha256,
  };

  factory ShardEnvelope.fromJson(Map<String, dynamic> j) {
    final exit = j['exitCode'];
    if (exit is! int) {
      throw const FormatException('envelope has no integer exitCode');
    }
    final schema = j['schema'];
    if (schema is! int) throw const FormatException('envelope has no schema');
    return ShardEnvelope(
      schema: schema,
      candidate: _str(j, 'candidate'),
      runId: _str(j, 'runId'),
      runAttempt: _str(j, 'runAttempt'),
      shard: _str(j, 'shard'),
      profile: _str(j, 'profile'),
      sdk: _str(j, 'sdk'),
      selectionDigest: _str(j, 'selectionDigest'),
      files: _strings(j, 'files'),
      exitCode: exit,
      completed: j['completed'] == true,
      emptySelection: j['emptySelection'] == true,
      streamSha256: j['streamSha256'] as String?,
      lcovSha256: j['lcovSha256'] as String?,
    );
  }
}

String _str(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is String && v.isNotEmpty) return v;
  throw FormatException('"$key" is missing or not a string');
}

List<String> _strings(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is List && v.every((e) => e is String)) {
    return [for (final e in v) e as String];
  }
  throw FormatException('"$key" is missing or not a list of strings');
}

/// One shard, read alone.
class ShardResult {
  ShardResult({
    required this.shard,
    required this.run,
    required this.exitCode,
    required this.violations,
    required this.lcovOk,
  });

  final String shard;

  /// The shard's own run; null when there was no readable envelope.
  final RunResult? run;

  /// The test process's exit code; null when no envelope said.
  final int? exitCode;

  /// Reasons this shard cannot be trusted. Empty means it is a faithful
  /// record of ONE complete run of the promised selection.
  final List<String> violations;
  final bool lcovOk;

  bool get ok =>
      violations.isEmpty &&
      exitCode == 0 &&
      run != null &&
      run!.completed &&
      run!.success &&
      run!.testsFailed == 0;
}

/// Reads one shard against [expected], inside [plan]. Never throws: every
/// way the evidence can be wrong is a violation.
ShardResult readShard({
  required ShardPlan plan,
  required ShardSpec expected,
  required ShardEnvelope? envelope,
  required String? stream,
  required String? lcov,
}) {
  final v = <String>[];
  ShardResult done(RunResult? run, int? exit, {required bool lcovOk}) => ShardResult(
    shard: expected.id,
    run: run,
    exitCode: exit,
    violations: v,
    lcovOk: lcovOk,
  );

  if (envelope == null) {
    v.add('no envelope was written: the shard job did not finish');
    return done(null, null, lcovOk: false);
  }
  if (envelope.schema != shardSchema) {
    v.add('envelope schema ${envelope.schema} is not $shardSchema');
  }
  if (envelope.shard != expected.id) {
    v.add(
      'the envelope is for shard "${envelope.shard}", not "${expected.id}"',
    );
  }
  if (envelope.candidate != plan.candidate) {
    v.add(
      'the envelope tested ${envelope.candidate}, the plan is for ${plan.candidate}',
    );
  }
  if (envelope.runId != plan.runId || envelope.runAttempt != plan.runAttempt) {
    v.add(
      'the envelope is from run ${envelope.runId}/${envelope.runAttempt}, '
      'the plan from ${plan.runId}/${plan.runAttempt}',
    );
  }
  if (envelope.selectionDigest != expected.digest) {
    v.add('the selection digest differs from the plan');
  }
  final sortedFiles = [...envelope.files]..sort();
  if (sortedFiles.join('\n') != expected.files.join('\n')) {
    v.add('the envelope lists other files than the plan selected');
  }
  if (!envelope.completed) {
    v.add(
      'the envelope never completed: the shard job died before it finished',
    );
  }

  // An explicit empty selection: nothing ran, nothing may be claimed.
  if (expected.files.isEmpty) {
    if (!expected.emptyAllowed) {
      v.add('an empty selection that the plan did not declare');
    }
    if (!envelope.emptySelection) {
      v.add('the plan selected nothing but the envelope does not say so');
    }
    if (stream != null && stream.trim().isNotEmpty) {
      v.add('an empty selection produced a test stream');
    }
    return done(
      RunResult(
        suites: {},
        completed: true,
        success: true,
        violations: const [],
      ),
      envelope.exitCode,
      lcovOk: true,
    );
  }
  if (envelope.emptySelection) {
    v.add(
      'the envelope declares an empty selection but the plan selected files',
    );
  }

  if (stream == null || stream.trim().isEmpty) {
    v.add('the test stream is missing');
    return done(null, envelope.exitCode, lcovOk: false);
  }
  if (envelope.streamSha256 == null ||
      envelope.streamSha256 != sha256Hex(stream)) {
    v.add('the stream does not match the hash the envelope recorded');
  }

  var lcovOk = true;
  if (expected.coverage) {
    if (lcov == null || lcov.trim().isEmpty) {
      v.add('the LCOV file is missing');
      lcovOk = false;
    } else if (!lcov.contains('SF:') || !lcov.contains('end_of_record')) {
      v.add('the LCOV file is not LCOV');
      lcovOk = false;
    } else if (envelope.lcovSha256 == null ||
        envelope.lcovSha256 != sha256Hex(lcov)) {
      v.add('the LCOV file does not match the hash the envelope recorded');
      lcovOk = false;
    }
  }

  final run = readRun(stream);
  v.addAll(run.violations);

  final loaded = run.suites.keys.toSet();
  final promised = expected.files.toSet();
  for (final p in loaded.difference(promised).toList()..sort()) {
    v.add('unexpected file in the stream: $p');
  }
  for (final p in promised.difference(loaded).toList()..sort()) {
    v.add('selected file never loaded: $p');
  }
  final declared = run.testsRun + run.suites.values.fold(0, (n, s) => n + s.skipped);
  if (declared == 0) v.add('the shard ran no test');
  if (envelope.exitCode != 0 && run.success && run.testsFailed == 0) {
    v.add(
      'the process exited ${envelope.exitCode} over a stream that reports success',
    );
  }
  return done(run, envelope.exitCode, lcovOk: lcovOk);
}

/// One shard's line in the report.
class ShardDiagnostic {
  ShardDiagnostic({
    required this.shard,
    required this.ok,
    required this.exitCode,
    required this.files,
    required this.tests,
    required this.failed,
    required this.violations,
  });

  final String shard;
  final bool ok;
  final int? exitCode;
  final int files;
  final int tests;
  final int failed;
  final int violations;

  String get line =>
      '$shard: ${ok ? 'ok' : 'FAILED'}, $tests tests in $files files'
      '${failed > 0 ? ', $failed failed' : ''}'
      '${exitCode == null
          ? ', no exit code'
          : exitCode != 0
          ? ', exit $exitCode'
          : ''}'
      '${violations > 0 ? ', $violations violations' : ''}';
}

/// The shards combined: [run] is the shape every row function reads.
class MergedRun {
  MergedRun({
    required this.run,
    required this.exitCode,
    required this.diagnostics,
  });
  final RunResult run;

  /// Zero only when every shard's process exited zero.
  final int exitCode;
  final List<ShardDiagnostic> diagnostics;

  String get summary => diagnostics.map((d) => d.line).join('; ');
}

/// Combines validated shard results under [plan]. Overall success is the
/// AND of every required shard; a shard that is missing, unreadable or
/// carries a violation makes the aggregate unreadable.
MergedRun mergeValidatedShards(
  ShardPlan plan,
  Map<String, ShardResult> results,
) {
  final violations = <String>[...plan.problems()];
  final suites = <String, SuiteResult>{};
  final diagnostics = <ShardDiagnostic>[];
  var completed = true;
  var success = true;
  var exit = 0;
  final known = plan.shards.map((s) => s.id).toSet();

  for (final id in results.keys.toList()..sort()) {
    if (!known.contains(id)) violations.add('[$id] is not in the plan');
  }
  for (final spec in plan.shards) {
    final r = results[spec.id];
    if (r == null) {
      violations.add('[${spec.id}] produced no result');
      completed = false;
      success = false;
      exit = exit == 0 ? 1 : exit;
      diagnostics.add(
        ShardDiagnostic(
          shard: spec.id,
          ok: false,
          exitCode: null,
          files: 0,
          tests: 0,
          failed: 0,
          violations: 1,
        ),
      );
      continue;
    }
    for (final m in r.violations) {
      violations.add('[${spec.id}] $m');
    }
    final run = r.run;
    if (run == null) {
      completed = false;
      success = false;
    } else {
      completed = completed && run.completed;
      success = success && run.success;
      for (final s in run.suites.values) {
        if (suites.containsKey(s.path)) {
          violations.add(
            '[${spec.id}] ${s.path} was already run by another shard',
          );
        } else {
          suites[s.path] = s;
        }
      }
    }
    final code = r.exitCode;
    if (code == null) {
      exit = exit == 0 ? 1 : exit;
    } else if (code != 0 && exit == 0) {
      exit = code;
    }
    diagnostics.add(
      ShardDiagnostic(
        shard: spec.id,
        ok: r.ok,
        exitCode: code,
        files: run?.suites.length ?? 0,
        tests: run?.testsRun ?? 0,
        failed: run?.testsFailed ?? 0,
        violations: r.violations.length,
      ),
    );
  }

  return MergedRun(
    run: RunResult(
      suites: suites,
      completed: completed,
      success: success,
      violations: violations,
    ),
    exitCode: exit,
    diagnostics: diagnostics,
  );
}
