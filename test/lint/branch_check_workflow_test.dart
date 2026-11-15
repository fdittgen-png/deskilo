// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4015, #4044 -- the branch check runs whatever paths a contributor names,
// each on a hosted runner of its own. Two things must hold for it to be worth trusting: the paths
// are refused before any tool starts unless each is a test path, and its
// verdict never reads a run that tested nothing as a pass.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _workflow = '.github/workflows/branch-check.yml';
const _summary = 'scripts/branch_check_summary.py';

List<YamlMap> _steps(String job) =>
    ((((loadYaml(File(_workflow).readAsStringSync()) as YamlMap)['jobs']
                    as YamlMap)[job]
                as YamlMap)['steps']
            as YamlList)
        .cast<YamlMap>();

YamlMap _job(String job) =>
    ((loadYaml(File(_workflow).readAsStringSync()) as YamlMap)['jobs']
            as YamlMap)[job]
        as YamlMap;

/// The verdict the summary prints for [events] and the run's exit [code].
List<String> _verdict(List<String> events, String code) {
  final dir = Directory.systemTemp.createTempSync('branch_check_');
  try {
    final stream = File('${dir.path}/stream.jsonl')
      ..writeAsStringSync(events.join('\n'));
    final result = Process.runSync('python3', [_summary, stream.path, code]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return '${result.stdout}'.trim().split('\n');
  } finally {
    dir.deleteSync(recursive: true);
  }
}

const _suite =
    '{"type":"suite","suite":{"id":0,"platform":"vm","path":"test/a_test.dart"}}';
String _start(int id, String name) =>
    '{"type":"testStart","test":{"id":$id,"name":"$name","suiteID":0}}';
String _done(int id, String result, {bool hidden = false, bool skip = false}) =>
    '{"type":"testDone","testID":$id,"result":"$result","hidden":$hidden,'
    '"skipped":$skip}';

void main() {
  test('the paths are checked by a job of their own, before any tool is '
      'installed, and only the checked list goes on', () {
    final steps = _steps('paths');
    final check = steps.singleWhere(
      (s) => s['name'] == 'The paths are test paths of this branch',
    );
    expect(
      steps.where((s) => '${s['uses']}'.startsWith('subosito/flutter-action')),
      isEmpty,
    );
    final guard = '${check['run']}';
    expect(guard, contains(r'^test/[A-Za-z0-9_./-]*$'));
    expect(guard, contains(r'"$p" == *..*'));
    expect(guard, contains(r'[ ! -e "$p" ]'));
    expect(guard, contains('at most 12 paths'));
    expect((check['env'] as YamlMap)['PATHS'], r'${{ inputs.paths }}');
    expect(
      (_job('paths')['outputs'] as YamlMap)['list'],
      r'${{ steps.check.outputs.list }}',
    );
  });

  test('each checked path runs on a runner of its own, and reaches the test '
      'command through the environment only', () {
    final job = _job('check');
    expect(job['needs'], 'paths');
    final strategy = job['strategy'] as YamlMap;
    expect(strategy['fail-fast'], isFalse);
    expect(
      (strategy['matrix'] as YamlMap)['path'],
      r'${{ fromJSON(needs.paths.outputs.list) }}',
    );
    final tests = _steps('check')
        .singleWhere((s) => s['name'] == 'Tests of this path');
    expect((tests['env'] as YamlMap)['CHECKED_PATH'], r'${{ matrix.path }}');
    final run = '${tests['run']}';
    expect(run, contains(r'"$CHECKED_PATH"'));
    expect(run, isNot(contains(r'${{')));
    expect(run, isNot(contains('PATHS')));
  });

  test('a path ends red when its tests did, after its verdict is written', () {
    final steps = _steps('check');
    final verdict = steps.indexWhere((s) => s['name'] == 'Verdict');
    final gate = steps.indexWhere((s) => s['name'] == 'Gate');
    expect(verdict, isNonNegative);
    expect(verdict, lessThan(gate));
    expect(steps[verdict]['if'], 'always()');
    expect('${steps[gate]['run']}'.trim(), r'[ "${CODE:-1}" = "0" ]');
  });

  test('the script that starts a run refuses the same paths', () {
    final script = File('scripts/branch_check.sh').readAsStringSync();
    expect(script, contains(r'^test/[A-Za-z0-9_./-]*$'));
    expect(script, contains(r'"$p" == *..*'));
  });

  group('the total of several paths', () {
    List<String> total(List<String> lines, int asked, String conclusion) {
      final process = Process.runSync('bash', [
        '-c',
        'printf "%s\\n" "\$@" | python3 scripts/branch_check_total.py '
            '$asked $conclusion',
        'total',
        ...lines,
      ]);
      return '${process.stdout}'.trim().split('\n');
    }

    const a = 'BRANCH CHECK: ok -- 10 passed, 1 skipped [test/a]';
    const b = 'BRANCH CHECK: ok -- 7 passed, 0 skipped [test/b]';
    const red =
        'BRANCH CHECK: FAILED -- 5 passed, 2 failed, 0 skipped (exit 1) '
        '[test/b]';

    test('adds what every path counted', () {
      expect(total([a, b], 2, 'success'), [
        'BRANCH CHECK: ok -- 17 passed, 1 skipped (2 paths)',
      ]);
    });

    test('a failing path fails the total and keeps its own line and names', () {
      expect(total([a, red, '- test/b/x_test.dart: one'], 2, 'failure'), [
        'BRANCH CHECK: FAILED -- 15 passed, 2 failed, 1 skipped '
            '(1 of 2 paths)',
        red,
        '- test/b/x_test.dart: one',
      ]);
    });

    test('a path that gave no verdict is a failure that says so', () {
      expect(total([a], 2, 'cancelled'), [
        'BRANCH CHECK: FAILED -- 10 passed, 0 failed, 1 of 2 paths gave no '
            'verdict, 1 skipped (0 of 2 paths)',
      ]);
    });

    test('a run that did not end in success is not ok although every '
        'verdict read ok', () {
      expect(
        total([a, b], 2, 'failure').single,
        startsWith(
          'BRANCH CHECK: FAILED -- 17 passed, 0 failed, the run ended failure',
        ),
      );
    });
  });

  group('the verdict', () {
    test('counts what passed and what was skipped, and leaves out the '
        'loading entries', () {
      expect(
        _verdict([
          _suite,
          _start(1, 'loading test/a_test.dart'),
          _done(1, 'success', hidden: true),
          _start(2, 'one'),
          _done(2, 'success'),
          _start(3, 'two'),
          _done(3, 'success', skip: true),
        ], '0'),
        ['BRANCH CHECK: ok -- 1 passed, 1 skipped'],
      );
    });

    test('names every test that failed, its file first', () {
      expect(
        _verdict([
          _suite,
          _start(2, 'one'),
          _done(2, 'success'),
          _start(3, 'two'),
          _done(3, 'failure'),
          _start(4, 'three'),
          _done(4, 'error'),
        ], '1'),
        [
          'BRANCH CHECK: FAILED -- 1 passed, 2 failed, 0 skipped (exit 1)',
          '- test/a_test.dart: two',
          '- test/a_test.dart: three',
        ],
      );
    });

    test(
      'a run in which no test ran is a failure, whatever it exited with',
      () {
        expect(_verdict([_suite], '0'), [
          'BRANCH CHECK: FAILED -- 0 passed, no test ran, 0 skipped (exit 0)',
        ]);
      },
    );

    test('a run that exited red with every test green is a failure', () {
      expect(_verdict([_suite, _start(2, 'one'), _done(2, 'success')], '1'), [
        'BRANCH CHECK: FAILED -- 1 passed, 0 failed, 0 skipped (exit 1)',
      ]);
    });

    test('with a path, the line ends with it', () {
      final dir = Directory.systemTemp.createTempSync('branch_check_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final stream = File('${dir.path}/stream.jsonl')
        ..writeAsStringSync(
          [_suite, _start(2, 'one'), _done(2, 'success')].join('\n'),
        );
      final result = Process.runSync('python3', [
        _summary,
        stream.path,
        '0',
        'test/ux',
      ]);
      expect(
        '${result.stdout}'.trim(),
        'BRANCH CHECK: ok -- 1 passed, 0 skipped [test/ux]',
      );
    });

    test('a missing stream is a failure that says so', () {
      final result = Process.runSync('python3', [
        _summary,
        'no/such.jsonl',
        '1',
      ]);
      expect(result.exitCode, 0);
      expect(
        '${result.stdout}',
        startsWith('BRANCH CHECK: FAILED -- no test stream'),
      );
    });
  });
}
