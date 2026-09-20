// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C1 — the discipline rows come from one test stream, and a stream
// that cannot be trusted makes red rows, never green ones.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/quality_rows/rows.dart';

const _manifest = '''
# name|job|kind|conditional|paths|evidence
Tests|code|step|||the whole suite
Architecture|code|tests||test/lint/layering_test.dart,test/lint/file_length_test.dart|layering and budgets
Accessibility|code|tests||test/a11y/|screens
Coverage|code|step|||by layer
Migration safety|database|step|||replay
''';

String _event(Map<String, Object?> e) => jsonEncode(e);

/// A stream with two files: `test/lint/layering_test.dart` (one test,
/// [layeringResult]) and `test/a11y/screens_test.dart` (two tests, one
/// skipped), ending in `done` unless [truncated].
String _stream({
  String layeringResult = 'success',
  bool truncated = false,
  bool loadError = false,
  bool errorOutsideTest = false,
  bool success = true,
}) {
  final lines = <String>[
    _event({'type': 'start', 'protocolVersion': '0.1.1'}),
    _event({'type': 'suite', 'suite': {'id': 0, 'platform': 'vm', 'path': '/repo/test/lint/layering_test.dart'}}),
    _event({'type': 'suite', 'suite': {'id': 1, 'platform': 'vm', 'path': '/repo/test/a11y/screens_test.dart'}}),
    _event({'type': 'testStart', 'test': {'id': 1, 'name': 'loading /repo/test/lint/layering_test.dart', 'suiteID': 0, 'groupIDs': <int>[]}}),
    _event({'type': 'testDone', 'testID': 1, 'result': loadError ? 'error' : 'success', 'hidden': !loadError, 'skipped': false}),
    _event({'type': 'testStart', 'test': {'id': 2, 'name': 'layers hold', 'suiteID': 0, 'groupIDs': <int>[]}}),
    _event({'type': 'testDone', 'testID': 2, 'result': layeringResult, 'hidden': false, 'skipped': false}),
    _event({'type': 'testStart', 'test': {'id': 3, 'name': 'screen a', 'suiteID': 1, 'groupIDs': <int>[]}}),
    _event({'type': 'testDone', 'testID': 3, 'result': 'success', 'hidden': false, 'skipped': false}),
    _event({'type': 'testStart', 'test': {'id': 4, 'name': 'screen b', 'suiteID': 1, 'groupIDs': <int>[]}}),
    _event({'type': 'testDone', 'testID': 4, 'result': 'success', 'hidden': false, 'skipped': true}),
    if (errorOutsideTest)
      _event({'type': 'error', 'testID': null, 'error': 'setUpAll blew up', 'isFailure': false}),
    if (!truncated) _event({'type': 'done', 'success': success}),
  ];
  return '${lines.join('\n')}\n';
}

void main() {
  final manifest = parseManifest(_manifest);

  test('the manifest reads every field, and marks conditional rows', () {
    expect(manifest.map((d) => d.name), [
      'Tests', 'Architecture', 'Accessibility', 'Coverage', 'Migration safety',
    ]);
    expect(manifest[1].paths, ['test/lint/layering_test.dart', 'test/lint/file_length_test.dart']);
    expect(manifest[2].covers('test/a11y/screens_test.dart'), isTrue);
    expect(manifest[2].covers('test/a11y_extra/x_test.dart'), isFalse);
    expect(manifest.every((d) => !d.conditional), isTrue);
  });

  test('a clean stream makes green rows with the counts, and skipped is '
      'counted as skipped', () {
    final run = readRun(_stream());
    expect(run.violations, isEmpty);
    final rows = deriveRows(manifest, run, job: 'code');
    expect(rows.map((r) => '${r.name}=${r.outcome}'),
        ['Architecture=success', 'Accessibility=success']);
    expect(rows[1].evidence, contains('1 tests, 1 skipped'));
    expect(suiteRow(run, exitCode: 0).outcome, 'success');
  });

  test('a failing test turns its discipline red and the suite row red, '
      'whatever the reporter printed', () {
    final run = readRun(_stream(layeringResult: 'failure', success: false));
    final rows = deriveRows(manifest, run, job: 'code');
    expect(rows.first.outcome, 'failure');
    expect(rows.first.evidence, contains('1 failed'));
    expect(rows[1].outcome, 'success', reason: 'the other discipline stands');
    expect(suiteRow(run, exitCode: 1).outcome, 'failure');
  });

  test('a passing stream with a nonzero exit code is not a pass', () {
    final run = readRun(_stream());
    expect(suiteRow(run, exitCode: 1).outcome, 'failure');
    expect(suiteRow(run, exitCode: 1).evidence, contains('exit 1'));
  });

  test('a stream cut short before done is a contract violation and every '
      'row is red', () {
    final run = readRun(_stream(truncated: true));
    expect(run.violations, contains(contains('cut short')));
    expect(deriveRows(manifest, run, job: 'code').every((r) => r.outcome == 'failure'),
        isTrue);
    expect(suiteRow(run, exitCode: 0).outcome, 'failure');
  });

  test('a file that failed to load is a failure of its discipline', () {
    final run = readRun(_stream(loadError: true));
    final rows = deriveRows(manifest, run, job: 'code');
    expect(rows.first.outcome, 'failure');
    expect(rows.first.evidence, contains('failed to load'));
  });

  test('an error outside any test is reported, not lost', () {
    final run = readRun(_stream(errorOutsideTest: true));
    expect(run.violations, contains(contains('setUpAll blew up')));
  });

  test('an empty stream, a malformed line and an unknown result are '
      'violations', () {
    expect(readRun('').violations, contains('the stream is empty'));
    expect(readRun('not json\n').violations, contains(contains('not JSON')));
    final odd = _stream().replaceFirst('"result":"success","hidden":false,"skipped":false}',
        '"result":"maybe","hidden":false,"skipped":false}');
    expect(readRun(odd).violations, contains(contains('unknown result')));
  });

  test('a discipline whose paths ran no test is red, not silently green', () {
    final only = parseManifest('Privacy|code|tests||test/lint/privacy_claims_test.dart|claims\n');
    final rows = deriveRows(only, readRun(_stream()), job: 'code');
    expect(rows.single.outcome, 'failure');
    expect(rows.single.evidence, contains('no test ran'));
  });
}
