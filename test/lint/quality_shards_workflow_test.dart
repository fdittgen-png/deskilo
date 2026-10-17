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
const _attempt = '-attempt-\${{ github.run_attempt }}';
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
        contains('testshard-$shard$_attempt'),
      );
      final upload = uploads.firstWhere(
        (u) =>
            '${(u['with'] as YamlMap)['name']}' == 'testshard-$shard$_attempt',
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

  // #2639 - a rerun is a new attempt of the same run: nothing one attempt
  // produced may stand in for another's evidence.
  group('artifacts are scoped to the attempt (#2639)', () {
    List<YamlMap> uses(String action) => [
      for (final job in _jobs().values)
        for (final s in (job as YamlMap)['steps'] as YamlList)
          if ('${(s as YamlMap)['uses']}'.startsWith(action)) s,
    ];

    List<String> downloads(String job) => [
      for (final s in (_jobs()[job] as YamlMap)['steps'] as YamlList)
        if ('${(s as YamlMap)['uses']}'.startsWith('actions/download-artifact'))
          '${(s['with'] as YamlMap)['name']}',
    ];

    test('every upload carries the attempt suffix and none overwrites', () {
      final ups = uses('actions/upload-artifact');
      expect(ups, isNotEmpty);
      for (final u in ups) {
        final w = u['with'] as YamlMap;
        expect('${w['name']}', endsWith(_attempt));
        expect(w.containsKey('overwrite'), isFalse);
      }
      final names = ups.map((u) => '${(u['with'] as YamlMap)['name']}');
      expect(
        names,
        containsAll([
          for (final n in const [
            'testshard-gate',
            'testshard-money',
            'testshard-rest',
            'quality-code',
            'quality-database',
            'quality-timings',
            'quality-report',
            'test-inventory',
          ])
            '$n$_attempt',
        ]),
      );
    });

    test('every download names one current-attempt artifact, never a '
        'pattern or a merge', () {
      final downs = uses('actions/download-artifact');
      expect(downs, isNotEmpty);
      for (final d in downs) {
        final w = d['with'] as YamlMap;
        expect(w.containsKey('pattern'), isFalse);
        expect(w.containsKey('merge-multiple'), isFalse);
        expect('${w['name']}', endsWith(_attempt));
      }
    });

    test('the aggregate downloads each shard into the directory the reader '
        'expects', () {
      final code = _jobs()['code'] as YamlMap;
      final got = {
        for (final d in (code['steps'] as YamlList).cast<YamlMap>().where(
          (s) => '${s['uses']}'.startsWith('actions/download-artifact'),
        ))
          '${(d['with'] as YamlMap)['name']}':
              '${(d['with'] as YamlMap)['path']}',
      };
      expect(got, {
        for (final id in _shardJobs.keys)
          'testshard-$id$_attempt': 'shards/testshard-$id',
      });
    });

    test('the report reads exactly classification, code and database rows '
        'and gates on each download', () {
      expect(downloads('report'), [
        'quality-classification$_attempt',
        'quality-code$_attempt',
        'quality-database$_attempt',
      ]);
      final gate = _run(_jobs()['report'] as YamlMap);
      for (final id in const ['dl_classification', 'dl_code', 'dl_database']) {
        expect(gate, contains('steps.$id.outcome'));
      }
    });

    test('the database job reads this attempt\'s classification', () {
      expect(downloads('database'), ['quality-classification$_attempt']);
    });
  });
}
