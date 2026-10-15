// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2388 — screen state belongs in a notifier, not in `setState`: form,
// selection and async-call state in the widget cannot be tested without
// pumping the whole screen and does not survive a rebuild of the parent.
// `setState` stays for ephemeral layout state (expanded, hover).
//
// The issue asked for no screen over 5 `setState` calls. Measured on
// 2026-10-11: 55 files are over 5, with 501 calls between them; moving
// each screen's state into a notifier is a rewrite of that screen, done
// when the screen is next changed. Until then this holds the line: no
// file outside the list grows past 5, and no listed file grows at all.
//
// #2598 — the list is `budgets.setState` in
// docs/design/CODE_HEALTH_BASELINE.json, written by
// `dart run tool/code_health.dart --baseline`; the reason a screen is on it
// is in docs/design/CODE_HEALTH_BUDGET_REASONS.txt. Counted per library: a
// screen split across part files is one screen (#2386).
import 'package:flutter_test/flutter_test.dart';

import '../../tool/code_health_budgets.dart';

void main() {
  test('setState: no new screen over 5, no listed screen grows', () {
    final failures = budgetFailures(Budgets.load(), measureBudgetActuals(),
        only: 'setState');
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
