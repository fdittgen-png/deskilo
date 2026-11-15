// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4015 -- the branch check runs whatever paths a contributor names, on a
// hosted runner. Two things must hold for it to be worth trusting: the paths
// are refused before any tool starts unless each is a test path, and its
// verdict never reads a run that tested nothing as a pass.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _workflow = '.github/workflows/branch-check.yml';
const _summary = 'scripts/branch_check_summary.py';

List<YamlMap> _steps() =>
    ((((loadYaml(File(_workflow).readAsStringSync()) as YamlMap)['jobs']
                    as YamlMap)['check']
                as YamlMap)['steps']
            as YamlList)
        .cast<YamlMap>();

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
  test('the paths are checked before any tool is installed, and only the '
      'checked list reaches the test command', () {
    final steps = _steps();
    final check = steps.indexWhere(
      (s) => s['name'] == 'The paths are test paths of this branch',
    );
    final flutter = steps.indexWhere(
      (s) => '${s['uses']}'.startsWith('subosito/flutter-action'),
    );
    final tests = steps.indexWhere(
      (s) => s['name'] == 'Tests of the named paths',
    );
    expect(check, isNonNegative);
    expect(check, lessThan(flutter));
    expect(flutter, lessThan(tests));
    final guard = '${steps[check]['run']}';
    expect(guard, contains(r'^test/[A-Za-z0-9_./-]*$'));
    expect(guard, contains(r'"$p" == *..*'));
    expect(guard, contains(r'[ ! -e "$p" ]'));
    expect((steps[check]['env'] as YamlMap)['PATHS'], r'${{ inputs.paths }}');
    // The test command reads the file the guard wrote, never the input.
    final run = '${steps[tests]['run']}';
    expect(run, contains('mapfile -t paths < branch-check-paths.txt'));
    expect(run, isNot(contains('PATHS')));
    expect(steps[tests]['env'], isNull);
  });

  test('the job ends red when the tests did, after the verdict is written', () {
    final steps = _steps();
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
