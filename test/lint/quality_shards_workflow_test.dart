// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2600 C2 — the sharded quality run is fail-closed by construction: the
// required context aggregates every shard whatever happened to it, each
// shard runs the selection the tool derives (never a list in the
// workflow), and every shard leaves the artifact the aggregate reads.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/quality_rows/selection.dart';

const _required = 'analyze · l10n gate · test · coverage';
const _shardJobs = {gateShard: 'gate', moneyShard: 'money', restShard: 'rest'};

YamlMap _jobs() =>
    (loadYaml(File('.github/workflows/quality.yml').readAsStringSync())
            as YamlMap)['jobs']
        as YamlMap;

String _run(YamlMap job) => (job['steps'] as YamlList)
    .map((s) => '${(s as YamlMap)['run'] ?? ''}')
    .join('\n');

void main() {
  test('every shard of the plan is a job that selects, runs and records '
      'exactly that shard', () {
    final jobs = _jobs();
    for (final MapEntry(key: shard, value: id) in _shardJobs.entries) {
      final job = jobs[id] as YamlMap;
      final run = _run(job);
      expect(run, contains('quality_shard.dart select --shard $shard '));
      expect(run, contains('quality_shard.dart envelope --shard $shard '));
      expect(
        run,
        contains('flutter test --coverage --concurrency "\$(nproc)"'),
        reason: 'concurrency is explicit, not the runner default',
      );
      expect(run, contains('--file-reporter json:shard/tests.jsonl'));
      expect('${job['timeout-minutes']}', '30');
      final uploads = [
        for (final s in job['steps'] as YamlList)
          if ('${(s as YamlMap)['uses']}'.startsWith('actions/upload-artifact'))
            s,
      ];
      expect(
        uploads.map((u) => '${(u['with'] as YamlMap)['name']}'),
        contains('testshard-$shard'),
      );
      final upload = uploads.firstWhere(
        (u) => '${(u['with'] as YamlMap)['name']}' == 'testshard-$shard',
      );
      expect(
        upload['if'],
        'always()',
        reason: 'diagnostics are uploaded, never skipped',
      );
      final tests = (job['steps'] as YamlList).cast<YamlMap>().firstWhere(
        (s) => s['id'] == 'tests',
      );
      expect(
        tests['continue-on-error'],
        isTrue,
        reason:
            'the exit is recorded in the envelope, then the Gate fails the job',
      );
      expect(run, contains('steps.tests.outcome'));
    }
    expect(_shardJobs.length, defaultShards(['test/a_test.dart']).length);
  });

  test('no workflow step lists test files or directories by hand', () {
    final jobs = _jobs();
    for (final id in _shardJobs.values) {
      expect(
        _run(jobs[id] as YamlMap),
        isNot(contains('test/features')),
        reason: 'the selection is the tool\'s walk of test/, not a list here',
      );
    }
  });

  test('the required context aggregates every shard, is always evaluated '
      'and gates on each result', () {
    final jobs = _jobs();
    final code = jobs['code'] as YamlMap;
    expect(code['name'], _required);
    expect(code['if'], 'always()');
    expect((code['needs'] as YamlList).toSet(), _shardJobs.values.toSet());
    final gate = _run(code).split('scripts/job_gate.sh').last;
    for (final id in _shardJobs.values) {
      expect(gate, contains('needs.$id.result'));
    }
    for (final step in const ['plan', 'rows', 'lcov', 'coverage']) {
      expect(gate, contains('steps.$step.outcome'));
    }
    final steps = (code['steps'] as YamlList).cast<YamlMap>();
    for (final id in const ['plan', 'rows', 'lcov', 'coverage']) {
      expect(steps.firstWhere((s) => s['id'] == id)['if'], 'always()');
    }
    expect(_run(code), contains('quality_rows.dart'));
    expect(_run(code), contains('--plan report/plan.json --shards shards'));
  });

  test('the report job waits for the shards too, and names their results', () {
    final report = _jobs()['report'] as YamlMap;
    expect(report['needs'] as YamlList, containsAll(_shardJobs.values));
    final gate = _run(report);
    for (final id in _shardJobs.values) {
      expect(gate, contains('needs.$id.result'));
    }
  });

  test('shard artifacts never match the report job\'s quality-* pattern', () {
    for (final id in _shardJobs.keys) {
      expect('testshard-$id', isNot(startsWith('quality-')));
    }
  });
}
