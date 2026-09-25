// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C2 — `scripts/job_gate.sh` is the last step of the code job, the
// database job and the report: it is green only when every outcome it
// is handed is exactly `success`. The invariant is that nothing but a
// success passes — a skipped step, a cancelled job, an outcome nobody
// recorded and a gate given no outcomes at all are each red, through
// the real script.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

({int code, String out}) _gate(List<String> pairs) {
  final r = Process.runSync('bash', ['scripts/job_gate.sh', ...pairs]);
  return (code: r.exitCode, out: '${r.stdout}${r.stderr}');
}

void main() {
  test('every outcome a success: green, and each is echoed by name', () {
    final r = _gate(['Tests=success', 'Coverage=success']);
    expect(r.code, 0, reason: r.out);
    expect(r.out, contains('Tests = success'));
    expect(r.out, contains('Coverage = success'));
  });

  test('one failure among successes is red, and the failure is named', () {
    final r = _gate(['Tests=success', 'Coverage=failure']);
    expect(r.code, 1);
    expect(r.out, contains("'Coverage' did not succeed: failure"));
    expect(r.out, isNot(contains("'Tests' did not succeed")));
  });

  test('skipped, cancelled, empty and unknown outcomes are not green', () {
    for (final outcome in ['skipped', 'cancelled', '', 'passed', 'true']) {
      final r = _gate(['Migration safety=$outcome', 'Tests=success']);
      expect(r.code, 1, reason: 'outcome "$outcome" passed: ${r.out}');
      expect(r.out, contains("'Migration safety' did not succeed"),
          reason: outcome);
    }
  });

  test('a pair without an outcome at all is red, not a parse accident', () {
    final r = _gate(['Tests']);
    expect(r.code, 1);
    expect(r.out, contains('no outcome was recorded'));
  });

  test('a gate handed nothing is red: an empty selection is not a pass', () {
    final r = _gate(const []);
    expect(r.code, 1);
    expect(r.out, contains('given no outcomes'));
  });
}
