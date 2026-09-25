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
//
// #1446 C3 — and MALFORMED evidence is not a score. The aggregation
// summed whatever LF:/LH: lines it met, so `LH:12 LF:10` was "core
// 120.0%" and a report truncated mid-record exited 0. The second group
// below feeds the real script every broken shape and expects it to stop
// BEFORE a percentage exists: no "coverage by layer:" line, no report/
// directory. Removing `validate_lcov` from the script turns them red.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An LCOV record for [file] with [found] lines, [hit] of them covered.
String _record(String file, {required int hit, required int found}) =>
    'TN:\nSF:$file\nLF:$found\nLH:$hit\nend_of_record\n';

/// domain 90%, presentation 90%, core 80%, total 86.6% — every floor met.
const _complete = 'TN:\nSF:lib/features/x/domain/a.dart\nLF:10\nLH:9\n'
    'end_of_record\nTN:\nSF:lib/features/x/presentation/b.dart\nLF:10\nLH:9\n'
    'end_of_record\nTN:\nSF:lib/core/c.dart\nLF:10\nLH:8\nend_of_record\n';

/// What `flutter test --coverage` actually writes (captured 2026-09-25
/// from one domain test): no TN:, DA: per line, LF:/LH: once, then
/// end_of_record. The fixture above is the same shape minus DA:, so this
/// is the pin that the producer's real output still parses.
const _producer = 'SF:lib/features/workspace/domain/workspace_branding.dart\n'
    'DA:20,1\nDA:21,1\nDA:22,3\nDA:24,3\nDA:28,1\nDA:29,5\nDA:32,1\nDA:41,1\n'
    'DA:42,0\nDA:43,1\nLF:10\nLH:9\nend_of_record\n'
    'SF:lib/features/workspace/presentation/branding_tile.dart\n'
    'DA:5,1\nDA:6,1\nDA:7,1\nDA:9,2\nDA:12,0\nLF:5\nLH:4\nend_of_record\n'
    'SF:lib/core/motion/motion_tokens.dart\n'
    'DA:3,1\nDA:4,1\nDA:8,1\nDA:9,0\nLF:4\nLH:3\nend_of_record\n';

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

  // ---- #1446 C3: the shape of the evidence -------------------------------

  test('the producer\'s real record shape is green — DA: lines and no TN:',
      () {
    final r = run(_producer);
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('domain 90.0%'));
    expect(r.out, contains('presentation 80.0%'));
    expect(r.out, contains('core 75.0%'));
    expect(r.out, contains('total 84.2%'));
  });

  /// Every malformed shape exits 1, names the line and what is wrong, and
  /// stops before any percentage is aggregated.
  void malformed(String what, String lcov, {required String names}) {
    final r = run(lcov);
    expect(r.code, 1, reason: '$what exited ${r.code}:\n${r.out}');
    expect(r.out, contains(names), reason: '$what:\n${r.out}');
    expect(r.out, contains('is malformed'), reason: '$what:\n${r.out}');
    expect(r.out, isNot(contains('coverage by layer:')),
        reason: '$what: a percentage was computed from malformed evidence');
    expect(r.out, isNot(contains('%')),
        reason: '$what: a percentage was printed from malformed evidence');
    expect(Directory('${_dir.path}/report').existsSync(), isFalse,
        reason: '$what: the report was written from malformed evidence');
  }

  test('more lines hit than exist is malformed, not 120%', () {
    // Exactly what scored "core 120.0%" and exited 0 before C3.
    malformed(
      'hits > found',
      _complete.replaceFirst(_record('lib/core/c.dart', hit: 8, found: 10),
          _record('lib/core/c.dart', hit: 12, found: 10)),
      names: 'line 15: LH:12 exceeds LF:10 for lib/core/c.dart',
    );
  });

  test('a report truncated before end_of_record is malformed, not a score',
      () {
    // The last record has its summaries but no terminator — exactly what
    // a reporter killed mid-write leaves behind; it scored 86.6% before.
    malformed(
      'truncated after LH',
      'TN:\nSF:lib/features/x/domain/a.dart\nLF:10\nLH:9\nend_of_record\n'
          'TN:\nSF:lib/features/x/presentation/b.dart\nLF:10\nLH:9\n'
          'end_of_record\nTN:\nSF:lib/core/c.dart\nLF:10\nLH:8\n',
      names: 'line 14: the report ends inside the record for lib/core/c.dart',
    );
    // Truncated right after SF: — the file silently contributed nothing.
    malformed(
      'truncated after SF',
      '${_complete}TN:\nSF:lib/core/d.dart\n',
      names: 'line 17: the report ends inside the record for lib/core/d.dart',
    );
    // A new SF: while the previous record is still open.
    malformed(
      'SF inside an open record',
      'TN:\nSF:lib/features/x/domain/a.dart\nLF:10\nLH:9\n$_complete',
      names: 'line 6: SF: while the record for lib/features/x/domain/a.dart '
          'is still open',
    );
    // A terminator and summaries that belong to no record.
    malformed(
      'orphan end_of_record',
      '${_complete}end_of_record\nLF:5\nLH:5\n',
      names: 'line 16: end_of_record without an open SF: record',
    );
  });

  test('a duplicate or missing LF:/LH: summary is malformed, not a score',
      () {
    const head = 'TN:\nSF:lib/features/x/domain/a.dart\nLF:10\nLH:9\n'
        'end_of_record\nTN:\nSF:lib/features/x/presentation/b.dart\nLF:10\n'
        'LH:9\nend_of_record\n';
    malformed(
      'duplicate LF',
      '${head}TN:\nSF:lib/core/c.dart\nLF:10\nLF:10\nLH:8\nend_of_record\n',
      names: 'line 14: duplicate LF: for lib/core/c.dart',
    );
    malformed(
      'duplicate LH',
      '${head}TN:\nSF:lib/core/c.dart\nLF:10\nLH:8\nLH:8\nend_of_record\n',
      names: 'line 15: duplicate LH: for lib/core/c.dart',
    );
    // No LF: — the file's hits were counted against nothing ("500.0%").
    malformed(
      'missing LF',
      '${head}TN:\nSF:lib/core/c.dart\nLH:8\nend_of_record\n'
          'TN:\nSF:lib/core/e.dart\nLF:2\nLH:2\nend_of_record\n',
      names: 'line 14: no LF: summary for lib/core/c.dart',
    );
    malformed(
      'missing LH',
      '${head}TN:\nSF:lib/core/c.dart\nLF:10\nend_of_record\n',
      names: 'line 14: no LH: summary for lib/core/c.dart',
    );
  });

  test('a count that is not a non-negative integer is malformed', () {
    for (final (value, line) in const [
      ('LF:ten', 13),
      ('LF:-10', 13),
      ('LH:-8', 14),
      ('LH:8.5', 14),
      ('LF:', 13),
      ('LH: 8', 14),
    ]) {
      final lcov = _complete.replaceFirst(
        _record('lib/core/c.dart', hit: 8, found: 10),
        'TN:\nSF:lib/core/c.dart\n${value.startsWith('LF') ? value : 'LF:10'}\n'
            '${value.startsWith('LH') ? value : 'LH:8'}\nend_of_record\n',
      );
      malformed(value, lcov,
          names: 'line $line: $value is not a non-negative integer count');
    }
  });

  test('a zero-line file is valid evidence, not a malformed one', () {
    // Files with nothing instrumentable are LF:0 LH:0 in real output.
    final r =
        run('$_complete${_record('lib/core/empty.dart', hit: 0, found: 0)}');
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('core 80.0%'));
  });
}
