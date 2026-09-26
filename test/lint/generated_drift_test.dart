// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C5a — the generated code is what build_runner writes, in the
// required job and in the F-Droid audit, through one script that is
// proved able to go red here: a rewritten `.g.dart`, a new one and a
// generator that dies each fail through the real script over a real
// temporary repository, and a clean tree is the green control.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _script = 'scripts/generated_drift.sh';
// YAML strips the block indentation: the continuation lines keep two spaces.
const _call = "bash scripts/generated_drift.sh \\\n"
    "  'dart run build_runner build --delete-conflicting-outputs' \\\n"
    "  -- '*.g.dart' '*.freezed.dart'";

List<YamlMap> _steps(String workflow, String job) {
  final w = loadYaml(File('.github/workflows/$workflow').readAsStringSync())
      as YamlMap;
  return (((w['jobs'] as YamlMap)[job] as YamlMap)['steps'] as YamlList)
      .cast<YamlMap>();
}

late Directory _dir;
({int code, String out}) _run(List<String> args) {
  final r = Process.runSync(
    'bash',
    ['${Directory.current.path}/$_script', ...args],
    workingDirectory: _dir.path,
  );
  return (code: r.exitCode, out: '${r.stdout}${r.stderr}');
}

void _git(List<String> args) {
  final r = Process.runSync('git',
      ['-c', 'user.name=t', '-c', 'user.email=t@t', ...args],
      workingDirectory: _dir.path);
  expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
}

void main() {
  test('the required job runs the gate after l10n and before the suite, '
      'and the F-Droid audit runs the same call, neither tolerated', () {
    for (final (workflow, job) in [
      ('quality.yml', 'code'),
      ('fdroid-foss.yml', 'foss-apk'),
    ]) {
      final steps = _steps(workflow, job);
      final i = steps.indexWhere((s) => '${s['run']}'.contains(_call));
      expect(i, isNonNegative, reason: '$workflow: no step makes the call');
      expect(steps[i]['continue-on-error'], isNull, reason: workflow);
      // In the audit the call shares a step with the suite: order by text.
      final script = steps.map((s) => '${s['run'] ?? ''}').join('\n');
      expect(script.indexOf(_call), lessThan(script.indexOf('flutter test')),
          reason: '$workflow: the gate precedes the suite');
      if (job == 'code') {
        final l10n = steps.indexWhere((s) => '${s['name']}'.startsWith('l10n gate'));
        expect(i, l10n + 1, reason: 'beside the l10n gate');
      }
    }
  });

  group('the real script over a real repository', () {
    setUp(() {
      _dir = Directory.systemTemp.createTempSync('generated-drift');
      _git(['init', '-q']);
      File('${_dir.path}/a.g.dart').writeAsStringSync('a\n');
      File('${_dir.path}/b.freezed.dart').writeAsStringSync('b\n');
      File('${_dir.path}/c.dart').writeAsStringSync('c\n');
      _git(['add', '.']);
      _git(['commit', '-q', '-m', 'seed']);
    });
    tearDown(() => _dir.deleteSync(recursive: true));

    test('a generator that changes nothing: green, and it says so', () {
      final r = _run(['true', '--', '*.g.dart', '*.freezed.dart']);
      expect(r.code, 0, reason: r.out);
      expect(r.out, contains('is what the generator writes'));
    });

    test('a rewritten generated file: red, named as modified', () {
      final r = _run(['printf x >> a.g.dart', '--', '*.g.dart', '*.freezed.dart']);
      expect(r.code, 1, reason: r.out);
      expect(r.out, contains('modified: a.g.dart'));
      expect(r.out, contains('::error::'));
    });

    test('a generated file the commit does not have: red, named as new', () {
      final r = _run(['printf x > d.freezed.dart', '--', '*.g.dart', '*.freezed.dart']);
      expect(r.code, 1, reason: r.out);
      expect(r.out, contains('new:      d.freezed.dart'));
    });

    test('a hand-written file outside the pathspecs is not this gate', () {
      final r = _run(['printf x >> c.dart', '--', '*.g.dart', '*.freezed.dart']);
      expect(r.code, 0, reason: r.out);
    });

    test('a generator that dies: exit 2, and nothing is compared', () {
      final r = _run(['printf x >> a.g.dart; exit 3', '--', '*.g.dart']);
      expect(r.code, 2, reason: r.out);
      expect(r.out, contains('the generator failed — nothing was compared'));
      expect(r.out, isNot(contains('modified: a.g.dart')));
    });

    test('a call without the separator or without a pathspec is usage', () {
      expect(_run(['true', '*.g.dart']).code, 64);
      expect(_run(['true', '--']).code, 64);
    });
  });
}
