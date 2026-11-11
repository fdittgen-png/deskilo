// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3663 -- a re-run of only the failed jobs does not run the jobs that passed
// again, so their rows exist only under the earlier attempt's number: the
// report reads each input from the newest attempt of the run that produced it
// (never a later one than its own), a job cancelled by a time limit is said to
// have not finished rather than to have failed the change, and the workflow
// wires the fallback in front of the gate.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<({int code, String out})> _run(
  String script,
  List<String> args, {
  String stdin = '',
}) async {
  final p = await Process.start('bash', [script, ...args]);
  p.stdin.write(stdin);
  await p.stdin.close();
  final out = await p.stdout.transform(utf8.decoder).join();
  final err = await p.stderr.transform(utf8.decoder).join();
  return (code: await p.exitCode, out: '$out$err'.trim());
}

void main() {
  const select = 'scripts/newest_attempt_artifact.sh';
  const names =
      'quality-code-attempt-1\n'
      'quality-database-attempt-1\n'
      'quality-database-attempt-2\n'
      'quality-classification-attempt-1\n'
      'quality-code-attempt-3\n'
      'quality-code-attempt-x\n'
      'testshard-gate-attempt-1\n';

  group('the newest attempt that produced an input', () {
    test('the current attempt when it produced it', () async {
      final r = await _run(select, ['quality-database', '2'], stdin: names);
      expect(r.code, 0);
      expect(r.out, 'quality-database-attempt-2');
    });

    test(
      'an earlier attempt when the current one did not run the job',
      () async {
        final r = await _run(select, [
          'quality-classification',
          '2',
        ], stdin: names);
        expect(r.out, 'quality-classification-attempt-1');
      },
    );

    test('never a LATER attempt than its own', () async {
      final r = await _run(select, ['quality-code', '2'], stdin: names);
      expect(r.out, 'quality-code-attempt-1', reason: 'attempt 3 is not 2\'s');
    });

    test('a number that is not a number is not an attempt', () async {
      final r = await _run(select, ['quality-code', '9'], stdin: names);
      expect(r.out, 'quality-code-attempt-3');
    });

    test('no attempt produced it: exit 1 and nothing printed', () async {
      final r = await _run(select, ['quality-nothing', '2'], stdin: names);
      expect(r.code, 1);
      expect(r.out, isEmpty);
    });

    test('another prefix never stands in', () async {
      final r = await _run(select, ['quality', '2'], stdin: names);
      expect(r.code, 1);
    });
  });

  group('the final gate', () {
    const gate = 'scripts/job_gate.sh';

    test('a cancelled job did not finish: said so, still not green', () async {
      final r = await _run(gate, ['quality · database=cancelled']);
      expect(r.code, 1);
      expect(r.out, contains('did not finish'));
      expect(r.out, contains('not a failure of the change'));
    });

    test('a failure is still a failure, and success passes', () async {
      final failed = await _run(gate, ['a=failure']);
      expect(failed.code, 1);
      expect(failed.out, contains('did not succeed'));
      expect((await _run(gate, ['a=success'])).code, 0);
    });
  });

  test('the report job looks for earlier attempts before it gates, and an '
      'input recovered that way counts as read', () {
    final wf = File('.github/workflows/quality.yml').readAsStringSync();
    expect(wf, contains('scripts/fallback_attempt_rows.sh'));
    for (final id in const ['dl_classification', 'dl_code', 'dl_database']) {
      expect(wf, contains("steps.earlier.outputs.$id == 'recovered'"));
    }
    expect(
      wf.indexOf('Rows an earlier attempt produced'),
      lessThan(wf.indexOf('DESKILO QUALITY REPORT')),
    );
  });

  test('a validator that does not answer is a notice, not a red check', () {
    final script = File('tool/einvoice/validate.sh').readAsStringSync();
    expect(script, contains('exit 3'));
    expect(script, contains('did not answer'));
    final wf = File('.github/workflows/einvoice-validate.yml')
        .readAsStringSync();
    expect(wf, contains('"\$code" = 3'));
    expect(wf, contains('::notice::the validator did not answer'));
    // Any other failure still fails the job.
    expect(wf, contains('exit "\$code"'));
  });
}
