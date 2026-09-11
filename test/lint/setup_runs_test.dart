// SPDX-License-Identifier: 0BSD
//
// `web/setup.html` is ~900 lines of dense JavaScript with no build step,
// and nothing in CI ever executed it. So a plain `ReferenceError` in one
// step shipped to the published questionnaire, and that step rendered
// NOTHING.
//
// That is not hypothetical. `avail` — read in the Fonctionnalités step
// but declared only inside a different step's closure — threw on the
// first feature row. Step 2 of 12 came up blank, and because `render()`
// threw before it drew the navigation, the wizard was a dead end with no
// message and no way forward. It is the step that decides every question
// the following ten ask.
//
// `tool/setup/step_harness.mjs` drives every step's `build()` and
// `check()` against a minimal DOM. It asks one question — does this code
// run — which is exactly the question nobody was asking.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every setup.html step builds and checks without throwing', () {
    final node = Process.runSync('node', ['--version']);
    if (node.exitCode != 0) {
      // Node is on every GitHub runner; a developer without it still gets
      // the rest of the suite rather than a red bar they cannot fix.
      markTestSkipped('node is not on PATH');
      return;
    }
    final r = Process.runSync('node', ['tool/setup/step_harness.mjs']);
    final out = '${r.stdout}${r.stderr}'.trim();
    expect(
      r.exitCode,
      0,
      reason: 'a step of the setup questionnaire throws — it would render '
          'blank on the published page:\n$out',
    );
    // A harness that silently stopped finding the steps would pass while
    // testing nothing.
    expect(out, contains('steps: 12'));
    expect(out, contains('features: 100'));
  });
}
