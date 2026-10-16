// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1305 S2 — "Something went wrong. Please try again." may only become rarer.
//
// `workspaceGenericError` is the sentence a screen falls back to when it
// has nothing better to say. Measured on master 2026-09-16: **182** uses in
// **86** files. Most are honest fallbacks behind `runGuarded`, which
// since #1305 answers the refusals any screen can meet — no permission, no
// session, already decided, changed meanwhile — and #1241's dropped
// connection before the fallback is ever shown. What remains is where a
// domain knows its own refusals and has not named them yet.
//
// #2598 — the per-file numbers are `budgets.genericError` in
// docs/design/CODE_HEALTH_BASELINE.json, written by
// `dart run tool/code_health.dart --baseline`; they only fall.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/code_health_budgets.dart';

void main() {
  test('no file grows a generic-error fallback (#1305)', () {
    final problems = budgetFailures(Budgets.load(), measureBudgetActuals(),
        only: 'genericError');
    expect(problems, isEmpty,
        reason: '${problems.join('\n')}\n\nSay what failed: a domain refusal '
            'gets its own sentence (see bookingErrorText), a generic refusal '
            'is already answered by runGuarded.');
  });
}
