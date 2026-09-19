// SPDX-License-Identifier: 0BSD
//
// #1446 / #1334 — the gate's own red controls.
//
// `scripts/quality_report.sh` is what makes the pipeline a gate: it
// renders the table AND decides the exit code, from the rows the jobs
// wrote and the manifest that says which rows must exist. Everything
// else in the pipeline is checked by something; the checker was not.
//
// A gate that cannot be shown to fail is a decoration, so each refusal
// is driven here through the real script: a discipline that regressed, a
// row whose job died, a row nobody declared, a `skipped` that is not
// allowed to be skipped, a `not_applicable` with no classifier verdict
// behind it, and the case where every artifact was lost.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifest = '''
# name|job|kind|conditional|paths|evidence
Tests|code|step|||the whole suite
Coverage|code|step|||by layer and in total
Tenant isolation|database|step|conditional||the tenancy sweep
''';

late Directory _dir;

/// Runs the real script over [rows] (one `name|outcome|detail` per line)
/// and optional `classification.txt` lines.
({int code, String out}) run(String rows, {String? classification}) {
  final reportDir = Directory('${_dir.path}/report')..createSync();
  File('${reportDir.path}/a.psv').writeAsStringSync(rows);
  final classificationFile = File('${reportDir.path}/classification.txt');
  if (classification != null) {
    classificationFile.writeAsStringSync(classification);
  }
  final manifest = File('${_dir.path}/manifest.psv')
    ..writeAsStringSync(_manifest);
  final r = Process.runSync(
    'bash',
    ['scripts/quality_report.sh', reportDir.path, manifest.path],
  );
  reportDir.deleteSync(recursive: true);
  return (code: r.exitCode, out: '${r.stdout}${r.stderr}');
}

void main() {
  setUp(() => _dir = Directory.systemTemp.createTempSync('quality-report'));
  tearDown(() => _dir.deleteSync(recursive: true));

  test('every expected row, every outcome a success: green, and the table '
      'says so', () {
    final r = run('Tests|success|1 234 tests\n'
        'Coverage|success|62% by layer\n'
        'Tenant isolation|success|41 tables\n');
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('✅ PASS'));
    expect(r.out, contains('1 234 tests'));
  });

  test('a discipline that regressed is red, and the report names it', () {
    final r = run('Tests|failure|3 tests failed\n'
        'Coverage|success|62%\n'
        'Tenant isolation|success|41 tables\n');
    expect(r.code, 1);
    expect(r.out, contains("'Tests' regressed"));
    expect(r.out, contains('❌ FAIL'));
  });

  test('a row whose job died is red — a missing row is not a pass', () {
    final r = run('Tests|success|1 234 tests\n'
        'Tenant isolation|success|41 tables\n');
    expect(r.code, 1);
    expect(r.out, contains("no row for 'Coverage'"));
  });

  test('a row nobody declared is red: a renamed step cannot slip out of '
      'the gate by arriving under a new name', () {
    final r = run('Tests|success|1 234 tests\n'
        'Coverage|success|62%\n'
        'Tenant isolation|success|41 tables\n'
        'Vibes|success|felt good\n');
    expect(r.code, 1);
    expect(r.out, contains("row 'Vibes' is not in"));
  });

  test('the same row twice is red — two artifacts, one truth', () {
    final r = run('Tests|success|1 234 tests\n'
        'Tests|success|1 234 tests\n'
        'Coverage|success|62%\n'
        'Tenant isolation|success|41 tables\n');
    expect(r.code, 1);
    expect(r.out, contains("2 rows for 'Tests'"));
  });

  test('skipped passes only where the manifest says a row waits on an '
      'earlier one', () {
    final conditional = run('Tests|success|1 234 tests\n'
        'Coverage|success|62%\n'
        'Tenant isolation|skipped|\n');
    expect(conditional.code, 0, reason: conditional.out);
    expect(conditional.out, contains('⏭️ SKIPPED'));

    final unconditional = run('Tests|success|1 234 tests\n'
        'Coverage|skipped|\n'
        'Tenant isolation|success|41 tables\n');
    expect(unconditional.code, 1);
    expect(unconditional.out, contains("'Coverage' did not run"));
  });

  test('not_applicable needs the classifier verdict on record', () {
    const rows = 'Tests|success|1 234 tests\n'
        'Coverage|success|62%\n'
        'Tenant isolation|not_applicable|\n';

    final claimed = run(rows);
    expect(claimed.code, 1, reason: 'no classification.txt behind the claim');
    expect(claimed.out, contains('without the classifier'));

    final onRecord = run(rows, classification: 'database|not_applicable|no '
        'database path changed|v1\n');
    expect(onRecord.code, 0, reason: onRecord.out);
    expect(onRecord.out, contains('➖ NOT APPLICABLE'));

    final wrongJob = run(rows, classification: 'code|not_applicable|x|v1\n');
    expect(wrongJob.code, 1,
        reason: 'a verdict about another job does not stand a row down');
  });

  test('every artifact lost is red, not an empty green table', () {
    final r = run('');
    expect(r.code, 1);
    expect(r.out, contains('no discipline reported a row'));
  });
}
