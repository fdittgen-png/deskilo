// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2600 C1 — a shard is validated ALONE, and only validated results are
// combined. One reporter stream has one `done`; a later shard's success
// must never certify an earlier shard that was cut short, and run-local
// numeric ids must never be mixed across shards.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/quality_rows/rows.dart';
import '../../tool/quality_rows/shard_io.dart';
import '../../tool/quality_rows/shards.dart';

String _event(Map<String, Object?> e) => jsonEncode(e);

/// A well-formed stream over [files]: one test each, ids restart at 0/1
/// in every call, exactly like two separate `flutter test` processes.
String _stream(
  List<String> files, {
  bool truncated = false,
  bool success = true,
  String result = 'success',
  bool duplicateStart = false,
  bool unfinished = false,
  bool duplicateDone = false,
  bool duplicateSuiteId = false,
}) {
  final lines = <String>[
    _event({'type': 'start', 'protocolVersion': '0.1.1'}),
  ];
  var test = 0;
  for (var i = 0; i < files.length; i++) {
    lines.add(
      _event({
        'type': 'suite',
        'suite': {'id': i, 'platform': 'vm', 'path': '/repo/${files[i]}'},
      }),
    );
  }
  if (duplicateSuiteId && files.length > 1) {
    lines.add(
      _event({
        'type': 'suite',
        'suite': {'id': 0, 'platform': 'vm', 'path': '/repo/${files[1]}'},
      }),
    );
  }
  for (var i = 0; i < files.length; i++) {
    test++;
    lines.add(
      _event({
        'type': 'testStart',
        'test': {
          'id': test,
          'name': 'case of ${files[i]}',
          'suiteID': i,
          'groupIDs': <int>[],
        },
      }),
    );
    if (duplicateStart) {
      lines.add(
        _event({
          'type': 'testStart',
          'test': {
            'id': test,
            'name': 'case of ${files[i]}',
            'suiteID': i,
            'groupIDs': <int>[],
          },
        }),
      );
    }
    if (unfinished && i == 0) continue;
    final done = {
      'type': 'testDone',
      'testID': test,
      'result': result,
      'hidden': false,
      'skipped': false,
    };
    lines.add(_event(done));
    if (duplicateDone) lines.add(_event(done));
  }
  if (!truncated) lines.add(_event({'type': 'done', 'success': success}));
  return '${lines.join('\n')}\n';
}

const _gate = ['test/lint/a_test.dart', 'test/tool/b_test.dart'];
const _money = ['test/features/money/c_test.dart'];
const _rest = [
  'test/features/mcp/d_test.dart',
  'test/features/rooms/e_test.dart',
];

ShardPlan _plan({List<ShardSpec>? shards}) => ShardPlan(
  candidate: 'abc123',
  runId: '42',
  runAttempt: '1',
  shards:
      shards ??
      [
        ShardSpec(id: 'gate', files: _gate),
        ShardSpec(id: 'money', files: _money),
        ShardSpec(id: 'rest', files: _rest),
      ],
);

ShardEnvelope _envelope(
  ShardPlan plan,
  ShardSpec spec,
  String? stream, {
  String? candidate,
  String? runId,
  String? runAttempt,
  String? digest,
  List<String>? files,
  int exitCode = 0,
  bool completed = true,
  bool lcov = true,
  String? streamSha,
  int schema = shardSchema,
  bool emptySelection = false,
}) => ShardEnvelope(
  schema: schema,
  candidate: candidate ?? plan.candidate,
  runId: runId ?? plan.runId,
  runAttempt: runAttempt ?? plan.runAttempt,
  shard: spec.id,
  profile: 'test profile',
  sdk: 'Flutter 3.47.5',
  selectionDigest: digest ?? spec.digest,
  files: files ?? spec.files,
  exitCode: exitCode,
  completed: completed,
  emptySelection: emptySelection,
  streamSha256: streamSha ?? (stream == null ? null : sha256Hex(stream)),
  lcovSha256: lcov ? sha256Hex(_lcov) : null,
);

const _lcov = 'SF:lib/a.dart\nDA:1,1\nend_of_record\n';

ShardResult _read(
  ShardPlan plan,
  ShardSpec spec, {
  String? stream,
  ShardEnvelope? envelope,
  bool withEnvelope = true,
  String? lcov = _lcov,
}) {
  final body = stream ?? _stream(spec.files);
  return readShard(
    plan: plan,
    expected: spec,
    envelope: withEnvelope ? (envelope ?? _envelope(plan, spec, body)) : null,
    stream: body,
    lcov: lcov,
  );
}

Map<String, ShardResult> _allGood(ShardPlan plan) => {
  for (final s in plan.shards) s.id: _read(plan, s),
};

void main() {
  test('three successful shards with IDENTICAL run-local ids merge, and every '
      'required file runs once', () {
    final plan = _plan();
    final merged = mergeValidatedShards(plan, _allGood(plan));
    expect(merged.run.violations, isEmpty);
    expect(merged.run.completed, isTrue);
    expect(merged.run.success, isTrue);
    expect(merged.run.suites.keys.toSet(), {..._gate, ..._money, ..._rest});
    expect(merged.run.testsRun, 5);
    expect(merged.exitCode, 0);
    expect(suiteRow(merged.run, exitCode: merged.exitCode).outcome, 'success');
    expect(merged.diagnostics.map((d) => d.shard), ['gate', 'money', 'rest']);
    expect(merged.diagnostics.every((d) => d.ok), isTrue);
  });

  test('a TRUNCATED first shard plus a successful later shard FAILS', () {
    final plan = _plan();
    final results = _allGood(plan);
    final gate = plan.shards.first;
    results['gate'] = _read(
      plan,
      gate,
      stream: _stream(gate.files, truncated: true),
    );
    final merged = mergeValidatedShards(plan, results);
    expect(merged.run.violations, contains(contains('[gate]')));
    expect(merged.run.violations, contains(contains('cut short')));
    expect(merged.run.completed, isFalse);
    expect(suiteRow(merged.run, exitCode: merged.exitCode).outcome, 'failure');
  });

  test('a shard that wrote no envelope fails the aggregate', () {
    final plan = _plan();
    final money = plan.shards[1];
    final results = _allGood(plan)
      ..['money'] = _read(plan, money, withEnvelope: false);
    final merged = mergeValidatedShards(plan, results);
    expect(merged.run.violations, contains(contains('[money] no envelope')));
    expect(suiteRow(merged.run, exitCode: 0).outcome, 'failure');
  });

  test('a shard whose result is absent altogether fails the aggregate', () {
    final plan = _plan();
    final results = _allGood(plan)..remove('rest');
    final merged = mergeValidatedShards(plan, results);
    expect(
      merged.run.violations,
      contains(contains('[rest] produced no result')),
    );
    expect(merged.run.completed, isFalse);
    expect(suiteRow(merged.run, exitCode: 0).outcome, 'failure');
  });

  test('a result for a shard the plan does not know fails the aggregate', () {
    final plan = _plan();
    final extra = ShardSpec(id: 'rogue', files: ['test/lint/z_test.dart']);
    final results = _allGood(plan)
      ..['rogue'] = _read(_plan(shards: [extra]), extra);
    final merged = mergeValidatedShards(plan, results);
    expect(
      merged.run.violations,
      contains(contains('[rogue] is not in the plan')),
    );
  });

  final bad = <String, ShardResult Function(ShardPlan, ShardSpec)>{
    'a missing stream': (p, s) => readShard(
      plan: p,
      expected: s,
      envelope: _envelope(p, s, null),
      stream: null,
      lcov: _lcov,
    ),
    'a stream whose hash differs from the envelope': (p, s) => _read(
      p,
      s,
      envelope: _envelope(p, s, _stream(s.files), streamSha: 'f' * 64),
    ),
    'an envelope that never completed': (p, s) => _read(
      p,
      s,
      envelope: _envelope(p, s, _stream(s.files), completed: false),
    ),
    'a missing LCOV': (p, s) => _read(p, s, lcov: null),
    'an LCOV whose hash differs': (p, s) =>
        _read(p, s, lcov: 'SF:other\nend_of_record\n'),
    'an envelope without an LCOV hash': (p, s) =>
        _read(p, s, envelope: _envelope(p, s, _stream(s.files), lcov: false)),
    'a wrong candidate': (p, s) => _read(
      p,
      s,
      envelope: _envelope(p, s, _stream(s.files), candidate: 'zzz'),
    ),
    'a wrong run id': (p, s) =>
        _read(p, s, envelope: _envelope(p, s, _stream(s.files), runId: '7')),
    'a wrong run attempt': (p, s) => _read(
      p,
      s,
      envelope: _envelope(p, s, _stream(s.files), runAttempt: '2'),
    ),
    'a wrong selection digest': (p, s) => _read(
      p,
      s,
      envelope: _envelope(p, s, _stream(s.files), digest: 'a' * 64),
    ),
    'a different file list under the right digest': (p, s) => _read(
      p,
      s,
      envelope: _envelope(
        p,
        s,
        _stream(s.files),
        files: ['test/lint/other_test.dart'],
      ),
    ),
    'a future schema version': (p, s) =>
        _read(p, s, envelope: _envelope(p, s, _stream(s.files), schema: 99)),
    'invalid JSON in the stream': (p, s) =>
        _read(p, s, stream: '${_stream(s.files)}{oops\n'),
    'an envelope for another shard': (p, s) => _read(
      p,
      s,
      envelope: _envelope(
        p,
        ShardSpec(id: 'other', files: s.files),
        _stream(s.files),
      ),
    ),
    'a duplicate test start': (p, s) =>
        _read(p, s, stream: _stream(s.files, duplicateStart: true)),
    'a duplicate test terminal': (p, s) =>
        _read(p, s, stream: _stream(s.files, duplicateDone: true)),
    'a test that never finished': (p, s) =>
        _read(p, s, stream: _stream(s.files, unfinished: true)),
    'a duplicate suite id': (p, s) =>
        _read(p, s, stream: _stream(s.files, duplicateSuiteId: true)),
    'a repeated terminal event': (p, s) => _read(
      p,
      s,
      stream:
          '${_stream(s.files)}${_event({'type': 'done', 'success': true})}\n',
    ),
    'a second reporter start': (p, s) =>
        _read(p, s, stream: '${_stream(s.files)}${_stream(s.files)}'),
    'an unexpected loaded file': (p, s) => _read(
      p,
      s,
      stream: _stream([...s.files, 'test/lint/intruder_test.dart']),
    ),
    'an expected file that never loaded': (p, s) =>
        _read(p, s, stream: _stream([s.files.first])),
    'a reporter reference outside the repository tests': (p, s) => _read(
      p,
      s,
      stream: _stream(['/etc/elsewhere.dart', ...s.files.skip(1)]),
    ),
    'a malformed event field': (p, s) => _read(
      p,
      s,
      stream: _stream(s.files).replaceFirst('"suiteID":0', '"suiteID":"zero"'),
    ),
  };
  for (final entry in bad.entries) {
    test('${entry.key} fails its shard and the aggregate, other shards '
        'notwithstanding', () {
      final plan = _plan();
      final spec = plan.shards.last;
      final results = _allGood(plan)..[spec.id] = entry.value(plan, spec);
      expect(results[spec.id]!.violations, isNotEmpty);
      expect(results[spec.id]!.ok, isFalse);
      final merged = mergeValidatedShards(plan, results);
      expect(merged.run.violations, isNotEmpty);
      expect(merged.run.violations.first, startsWith('[rest]'));
      expect(
        suiteRow(merged.run, exitCode: merged.exitCode).outcome,
        'failure',
      );
      expect(
        deriveRows(
          parseManifest('Row|code|tests||test/lint/,test/features/|x\n'),
          merged.run,
          job: 'code',
        ).single.outcome,
        'failure',
        reason: 'a contract violation makes every row red',
      );
    });
  }

  test('a nonzero exit is a result, not a contract violation: the stream is '
      'still read, the aggregate exit carries it', () {
    final plan = _plan();
    final money = plan.shards[1];
    final stream = _stream(money.files, result: 'failure', success: false);
    final results = _allGood(plan)
      ..['money'] = _read(
        plan,
        money,
        stream: stream,
        envelope: _envelope(plan, money, stream, exitCode: 1),
      );
    final merged = mergeValidatedShards(plan, results);
    expect(merged.exitCode, 1);
    expect(merged.run.success, isFalse);
    expect(merged.run.testsFailed, 1);
    expect(
      merged.run.violations,
      isEmpty,
      reason: 'the failure is a test result; rows name the discipline',
    );
    expect(suiteRow(merged.run, exitCode: merged.exitCode).outcome, 'failure');
    expect(
      merged.diagnostics.firstWhere((d) => d.shard == 'money').exitCode,
      1,
    );
  });

  test('exit zero over a stream whose done says failure is not a pass', () {
    final plan = _plan();
    final money = plan.shards[1];
    final results = _allGood(plan)
      ..['money'] = _read(
        plan,
        money,
        stream: _stream(money.files, success: false),
      );
    final merged = mergeValidatedShards(plan, results);
    expect(merged.run.success, isFalse);
    expect(suiteRow(merged.run, exitCode: merged.exitCode).outcome, 'failure');
  });

  test('one file selected by two shards is a duplicate selection', () {
    final plan = _plan(
      shards: [
        ShardSpec(id: 'gate', files: _gate),
        ShardSpec(id: 'money', files: [..._money, _gate.first]),
      ],
    );
    expect(plan.problems(), contains(contains('selected by both')));
    final merged = mergeValidatedShards(plan, _allGood(plan));
    expect(merged.run.violations, contains(contains('selected by both')));
    expect(suiteRow(merged.run, exitCode: 0).outcome, 'failure');
  });

  test('a duplicate inside one selection, a directory and a non-test entry '
      'are plan problems', () {
    final dup = _plan(
      shards: [
        ShardSpec(id: 'a', files: [_gate.first, _gate.first]),
      ],
    );
    expect(
      dup.problems(),
      contains(contains('lists test/lint/a_test.dart twice')),
    );
    final dir = _plan(
      shards: [
        ShardSpec(id: 'a', files: ['test/lint/']),
      ],
    );
    expect(dir.problems(), contains(contains('is not a single test file')));
    final dirAndFile = _plan(
      shards: [
        ShardSpec(id: 'a', files: ['test/lint', 'test/lint/a_test.dart']),
      ],
    );
    expect(
      dirAndFile.problems(),
      contains(contains('is not a single test file')),
    );
  });

  test('the plan must cover the required files exactly once: a missing and '
      'an unexpected file are named', () {
    final plan = _plan();
    final required = {..._gate, ..._money, ..._rest};
    expect(plan.problems(required: required), isEmpty);
    expect(
      plan.problems(required: {...required, 'test/new/f_test.dart'}),
      contains(contains('test/new/f_test.dart is selected by no shard')),
    );
    expect(
      plan.problems(required: required.difference({_money.first})),
      contains(contains('${_money.first} is not a required test file')),
    );
  });

  test('a declared empty selection is explicit; an undeclared one is not '
      'a pass, and zero work fails', () {
    final empty = ShardSpec(id: 'none', files: const [], emptyAllowed: true);
    final plan = _plan(
      shards: [
        ShardSpec(id: 'gate', files: _gate),
        empty,
      ],
    );
    final ok = readShard(
      plan: plan,
      expected: empty,
      envelope: _envelope(plan, empty, null, lcov: false, emptySelection: true),
      stream: null,
      lcov: null,
    );
    expect(ok.violations, isEmpty);
    final merged = mergeValidatedShards(plan, {
      'gate': _read(plan, plan.shards.first),
      'none': ok,
    });
    expect(merged.run.violations, isEmpty);
    expect(merged.run.testsRun, 2);

    // The same shard without the declaration: not allowed to be empty.
    final strict = ShardSpec(id: 'none', files: const []);
    final undeclared = readShard(
      plan: plan,
      expected: strict,
      envelope: _envelope(
        plan,
        strict,
        null,
        lcov: false,
        emptySelection: true,
      ),
      stream: null,
      lcov: null,
    );
    expect(undeclared.violations, contains(contains('empty selection')));

    // Only empty shards: nothing ran, so the suite row cannot pass.
    final onlyEmpty = _plan(shards: [empty]);
    final zero = mergeValidatedShards(onlyEmpty, {
      'none': readShard(
        plan: onlyEmpty,
        expected: empty,
        envelope: _envelope(
          onlyEmpty,
          empty,
          null,
          lcov: false,
          emptySelection: true,
        ),
        stream: null,
        lcov: null,
      ),
    });
    expect(suiteRow(zero.run, exitCode: 0).outcome, 'failure');
  });

  test('a non-empty shard that ran no test is a violation, not an empty '
      'success', () {
    final plan = _plan();
    final spec = plan.shards.first;
    final noTests = [
      _event({'type': 'start', 'protocolVersion': '0.1.1'}),
      for (var i = 0; i < spec.files.length; i++)
        _event({
          'type': 'suite',
          'suite': {
            'id': i,
            'platform': 'vm',
            'path': '/repo/${spec.files[i]}',
          },
        }),
      _event({'type': 'done', 'success': true}),
    ].join('\n');
    final result = _read(plan, spec, stream: '$noTests\n');
    expect(result.violations, contains(contains('ran no test')));
  });

  test('legitimate skips keep their old meaning, and the strict rows still '
      'refuse them across shards', () {
    final plan = _plan();
    final money = plan.shards[1];
    final skippedStream = _stream(money.files).replaceFirst(
      '"hidden":false,"skipped":false',
      '"hidden":false,"skipped":true',
    );
    final results = _allGood(plan)
      ..['money'] = _read(plan, money, stream: skippedStream);
    final merged = mergeValidatedShards(plan, results);
    expect(merged.run.violations, isEmpty);
    final lax = parseManifest('Money|code|tests||test/features/money/|x\n');
    final strict = parseManifest(
      'Money|code|tests|strict|test/features/money/|x\n',
    );
    expect(merged.run.suites[_money.first]!.skipped, 1);
    expect(
      deriveRows(lax, merged.run, job: 'code').single.outcome,
      'failure',
      reason: 'the only test skipped, so nothing ran: unchanged semantics',
    );
    final two = ShardSpec(
      id: 'money',
      files: [
        'test/features/money/c_test.dart',
        'test/features/money/g_test.dart',
      ],
    );
    final plan2 = _plan(shards: [two]);
    final s2 = _stream(two.files).replaceFirst(
      '"hidden":false,"skipped":false',
      '"hidden":false,"skipped":true',
    );
    final m2 = mergeValidatedShards(plan2, {
      'money': _read(plan2, two, stream: s2),
    });
    expect(deriveRows(lax, m2.run, job: 'code').single.outcome, 'success');
    expect(deriveRows(strict, m2.run, job: 'code').single.outcome, 'failure');
  });

  test(
    'disciplines span shards: paths in different shards add up in one row',
    () {
      final plan = _plan();
      final merged = mergeValidatedShards(plan, _allGood(plan));
      final rows = deriveRows(
        parseManifest(
          'Span|code|tests||test/lint/a_test.dart,test/features/money/,test/features/mcp/|x\n',
        ),
        merged.run,
        job: 'code',
      );
      expect(rows.single.outcome, 'success');
      expect(rows.single.evidence, contains('3 tests'));
    },
  );

  test('the selection digest is order-independent and content-sensitive', () {
    expect(selectionDigest(['b', 'a']), selectionDigest(['a', 'b']));
    expect(selectionDigest(['a']), isNot(selectionDigest(['a', 'b'])));
    expect(selectionDigest(const []), hasLength(64));
  });

  test('plan and envelope round-trip through JSON', () {
    final plan = _plan();
    final again = ShardPlan.fromJson(
      jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>,
    );
    expect(again.candidate, plan.candidate);
    expect(again.shards.map((s) => s.digest), plan.shards.map((s) => s.digest));
    final env = _envelope(plan, plan.shards.first, _stream(_gate));
    final back = ShardEnvelope.fromJson(
      jsonDecode(jsonEncode(env.toJson())) as Map<String, dynamic>,
    );
    expect(back.selectionDigest, env.selectionDigest);
    expect(back.streamSha256, env.streamSha256);
    expect(() => ShardEnvelope.fromJson({'schema': 1}), throwsFormatException);
  });

  group('the CLIs read a shard directory', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('shards'));
    tearDown(() => dir.deleteSync(recursive: true));

    void write(ShardPlan plan, ShardSpec spec, {String? stream, bool truncated = false}) {
      final body = stream ?? _stream(spec.files, truncated: truncated);
      final d = Directory('${dir.path}/$shardArtifactPrefix${spec.id}')..createSync(recursive: true);
      File('${d.path}/tests.jsonl').writeAsStringSync(body);
      File('${d.path}/lcov.info').writeAsStringSync(_lcov);
      File('${d.path}/envelope.json')
          .writeAsStringSync(jsonEncode(_envelope(plan, spec, body).toJson()));
    }

    // `dart <file>`, not `dart run`: the latter first runs the package's
    // build hooks, which failed in CI beside other suites ("File not
    // formatted as yaml", exit 254) and left this test without output.
    ProcessResult rows(ShardPlan plan) {
      File('${dir.path}/plan.json').writeAsStringSync(jsonEncode(plan.toJson()));
      return Process.runSync('dart', [
        'tool/quality_rows.dart',
        '--plan', '${dir.path}/plan.json',
        '--shards', dir.path,
        '--manifest', '.github/quality-manifest.psv',
        '--out', '${dir.path}/tests.psv',
      ]);
    }

    test('complete shards: exit 0 and a green Tests row naming each shard', () {
      final plan = _plan();
      for (final s in plan.shards) {
        write(plan, s);
      }
      final r = rows(plan);
      final out = File('${dir.path}/tests.psv');
      expect(
        out.existsSync(),
        isTrue,
        reason: 'the rows CLI wrote nothing: exit ${r.exitCode}\n'
            '${r.stdout}\n${r.stderr}',
      );
      final psv = out.readAsStringSync();
      expect(psv, startsWith('Tests|success|5 tests in 5 files'));
      expect(psv, contains('gate: ok'));
      // The repository manifest names disciplines these fixtures do not
      // run, so their rows are red; the process verdict is about the
      // stream contract, which is intact.
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });

    test('a truncated first shard beside two good ones exits 1', () {
      final plan = _plan();
      for (final s in plan.shards) {
        write(plan, s, truncated: s.id == 'gate');
      }
      final r = rows(plan);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect(File('${dir.path}/tests.psv').readAsStringSync(), startsWith('Tests|failure|'));
      expect(r.stderr, contains('[gate]'));
    });

    test('a shard whose artifact never arrived exits 1', () {
      final plan = _plan();
      write(plan, plan.shards[0]);
      write(plan, plan.shards[1]);
      final r = rows(plan);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect(r.stderr, contains('[rest]'));
    });

    test('a partial retry fails closed: gate and rest from attempt 1 beside '
        'money from attempt 2 under an attempt-2 plan (#2639)', () {
      final first = _plan();
      final second = ShardPlan(
        candidate: first.candidate,
        runId: first.runId,
        runAttempt: '2',
        shards: first.shards,
      );
      for (final s in first.shards) {
        write(s.id == 'money' ? second : first, s);
      }
      final r = rows(second);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect(
        File('${dir.path}/tests.psv').readAsStringSync(),
        startsWith('Tests|failure|'),
      );
      expect(r.stderr, contains('[gate]'));
      expect(r.stderr, contains('[rest]'));
      expect(r.stderr, isNot(contains('[money]')));
      expect(r.stderr, contains('without --failed'));
    });

    test('a coherent retry: every shard from attempt 2 is accepted (#2639)', () {
      final first = _plan();
      final second = ShardPlan(
        candidate: first.candidate,
        runId: first.runId,
        runAttempt: '2',
        shards: first.shards,
      );
      for (final s in second.shards) {
        write(second, s);
      }
      final r = rows(second);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(
        File('${dir.path}/tests.psv').readAsStringSync(),
        startsWith('Tests|success|5 tests in 5 files'),
      );
    });

    test('an unreadable plan exits 1 with a red Tests row', () {
      File('${dir.path}/plan.json').writeAsStringSync('{');
      final r = Process.runSync('dart', [
        'tool/quality_rows.dart',
        '--plan', '${dir.path}/plan.json',
        '--shards', dir.path,
        '--manifest', '.github/quality-manifest.psv',
        '--out', '${dir.path}/tests.psv',
      ]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect(File('${dir.path}/tests.psv').readAsStringSync(), contains('Tests|failure|'));
    });
  });
}
