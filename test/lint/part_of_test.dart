// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2491 — `part of` does not grow.
//
// A `part` split makes a smaller file, not a smaller responsibility: the
// pieces share one library, one namespace and one reading order, and the
// metrics treat each as a file of its own. A split must create a class, a
// widget or a function with its own responsibility. The count may fall (a
// part that becomes a real file lowers it) and never rise.
//
// #2598 — the ceiling is `budgets.partOfFiles` in
// docs/design/CODE_HEALTH_BASELINE.json, written by
// `dart run tool/code_health.dart --baseline`.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/code_health_budgets.dart';

void main() {
  test('the number of `part of` files under lib/ only falls (#2491)', () {
    final failures = budgetFailures(Budgets.load(), measureBudgetActuals(),
        only: 'partOfFiles');
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
