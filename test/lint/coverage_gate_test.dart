// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 R2 — the coverage gate's own red controls.
//
// `scripts/coverage_gate.sh` is the step that turns a coverage run into a
// merge decision, and it had a hole: a layer with no measured lines
// printed a warning and returned without setting `fail`. An LCOV holding
// one core file and nothing else scored core 100%, total 100% and exited
// 0 — the three floors passed because two of them were never measured.
//
// Absent evidence is not a pass. These drive the real script over
// fixtures: a complete valid report is green, and every way the evidence
// can be missing, partial or below a floor is red, each naming what is
// wrong. Removing the fix in the script turns the first four red.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An LCOV record for [file] with [found] lines, [hit] of them covered.
String _record(String file, {required int hit, required int found}) =>
    'TN:\nSF:$file\nLF:$found\nLH:$hit\nend_of_record\n';

/// domain 90%, presentation 90%, core 80%, total 86.6% — every floor met.
const _complete = 'TN:\nSF:lib/features/x/domain/a.dart\nLF:10\nLH:9\n'
    'end_of_record\nTN:\nSF:lib/features/x/presentation/b.dart\nLF:10\nLH:9\n'
    'end_of_record\nTN:\nSF:lib/core/c.dart\nLF:10\nLH:8\nend_of_record\n';

late Directory _dir;
late String _script;

({int code, String out}) run(String lcov) {
  final file = File('${_dir.path}/lcov.info')..writeAsStringSync(lcov);
  final r = Process.runSync(
    'bash',
    [_script, file.path],
    workingDirectory: _dir.path,
  );
  return (code: r.exitCode, out: '${r.stdout}${r.stderr}');
}

void main() {
  setUpAll(() => _script = File('scripts/coverage_gate.sh').absolute.path);
  setUp(() => _dir = Directory.systemTemp.createTempSync('coverage-gate'));
  tearDown(() => _dir.deleteSync(recursive: true));

  test('a complete report over every floor is green, and says each layer',
      () {
    final r = run(_complete);
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('domain 90.0%'));
    expect(r.out, contains('presentation 90.0%'));
    expect(r.out, contains('core 80.0%'));
  });

  test('a layer with no measured lines fails, and is named', () {
    // The exact fixture from the audit: one core file, nothing else.
    final r = run(_record('lib/core/only.dart', hit: 1, found: 1));
    expect(r.code, 1, reason: 'missing evidence scored 100% and exited 0');
    expect(r.out, contains('domain has NO coverage evidence'));
    expect(r.out, contains('presentation has NO coverage evidence'));
  });

  test('each floor still refuses a real regression', () {
    for (final layer in const {
      'lib/features/x/domain/a.dart': 'domain coverage',
      'lib/features/x/presentation/b.dart': 'presentation coverage',
      'lib/core/c.dart': 'core coverage',
    }.entries) {
      // Every layer present, the one under test at 10%.
      final lcov = _complete.replaceFirst(
        _record(layer.key,
            hit: layer.key.contains('/core/') ? 8 : 9, found: 10),
        _record(layer.key, hit: 1, found: 10),
      );
      final r = run(lcov);
      expect(r.code, 1, reason: '${layer.key}\n${r.out}');
      expect(r.out, contains(layer.value), reason: r.out);
      expect(r.out, contains('below its'), reason: r.out);
    }
  });

  test('the total floor still refuses a regression', () {
    // Every layer over its own floor is not enough: 60% in total is not.
    final r = run('$_complete${_record('lib/data/d.dart', hit: 0, found: 40)}');
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('below the 65% gate'));
  });

  test('an empty, malformed or non-lib report is a reporting failure, not a '
      'score', () {
    expect(run('').code, 1);
    expect(run('').out, contains('empty'));

    final garbage = run('this is not an lcov report\n');
    expect(garbage.code, 1);
    expect(garbage.out, contains('not an LCOV report'));

    // Well-formed, but nothing of the application was measured.
    final elsewhere = run(_record('tool/generator.dart', hit: 1, found: 1));
    expect(elsewhere.code, 1);
    expect(elsewhere.out, contains('measures nothing'));
  });
}
