// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1635 E2 — web/cost_planner.js has no build step, so its hand-calculated
// fixtures run under node here, the same way the setup questionnaire's
// steps do (setup_runs_test.dart).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the cost planner passes its hand-calculated fixtures', () {
    final node = Process.runSync('node', ['--version']);
    if (node.exitCode != 0) {
      markTestSkipped('node is not on PATH');
      return;
    }
    final r = Process.runSync('node', ['tool/web/cost_planner_test.mjs']);
    final out = '${r.stdout}${r.stderr}'.trim();
    expect(r.exitCode, 0, reason: out);
    // A harness that stopped finding its cases would pass testing nothing.
    expect(out, contains('cost planner: 12 cases passed'));
  });
}
