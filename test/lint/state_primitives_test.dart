// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1305 S1 — an empty list must never look like a failed one.
//
// The app already has the primitives: `LoadingView`, `EmptyState`,
// `InlineBanner`, `AppSnack` and `runGuarded`. Across lib/ they are used
// 48, 21 and 16 times respectively. What undercuts them is the raw
// `CircularProgressIndicator` dropped straight into a screen: it says
// "something is happening" and nothing else — not what is loading, not
// whether existing content is still valid, not what to do if it never
// finishes.
//
// Measured on master 2026-09-16: **15** raw spinners, in 15 different
// files, one each. (#1305's brief says 14; the code says 15. The code
// is authoritative and the difference is why this is a measurement
// rather than a transcription.)
//
// ## Why a ratchet and not a ban
//
// Some of the 15 are legitimate: a 24×24 spinner inside a button that
// has already been pressed is not a screen state, it is a control
// state, and `LoadingView` would be wrong there. Sorting the honest
// ones from the lazy ones is a per-file judgement nobody has made yet.
//
// So this counts them and refuses to let the number grow. The per-file
// numbers are `budgets.rawSpinner` in docs/design/CODE_HEALTH_BASELINE.json
// (#2598), written by `dart run tool/code_health.dart --baseline`; a file
// that adopts a primitive drops out of it there.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/code_health_budgets.dart';
import 'lint_sources.dart';

/// The primitives a screen state should be expressed with. Counted so a
/// fall in spinners that is really a fall in *state handling* is
/// visible: removing a spinner and showing nothing is not progress.
const _primitives = ['LoadingView(', 'EmptyState(', 'InlineBanner('];

void main() {
  test('no presentation file grows a raw spinner (#1305)', () {
    final problems = budgetFailures(Budgets.load(), measureBudgetActuals(),
        only: 'rawSpinner');
    expect(
      problems,
      isEmpty,
      reason: 'a raw CircularProgressIndicator says "something is '
          'happening" and nothing else — not what is loading, not '
          'whether what is on screen is still valid, not what to do if '
          'it never finishes:\n${problems.join('\n')}\n\n'
          'Use LoadingView for a screen that has no data yet, keep '
          'existing content visible while refreshing, and say what '
          'failed with InlineBanner or AppSnack (#1305).',
    );
  });

  test('the state primitives are still the house idiom', () {
    // A guard on the guard: if somebody "fixed" the spinner count by
    // deleting the primitives instead of adopting them, the ratchet
    // above would read as progress. Counting both sides makes that
    // visible.
    var primitives = 0;
    for (final file in handWrittenDartFiles('lib')) {
      final source = file.readAsStringSync();
      for (final primitive in _primitives) {
        primitives += primitive.allMatches(source).length;
      }
    }

    expect(
      primitives,
      greaterThanOrEqualTo(80),
      reason: 'LoadingView + EmptyState + InlineBanner were used 85 '
          'times across lib/ on 2026-09-16 (48 + 21 + 16). A sharp fall '
          'means screens stopped expressing their state rather than '
          'started — which is what the spinner ratchet would otherwise '
          'reward. The floor sits a little under the measurement so an '
          'honest refactor that merges two call sites does not fail it.',
    );
  });
}
