// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1304 S1 — a screen does not choose its own font size or its own colour.
//
// The theme already owns both: `TextTheme` roles for type, `ColorScheme`
// plus `AppStatusColors` / `SeatStateColors` / `OfficeColors` for colour,
// all measured by `contrast_test`. A `fontSize:` or a `Color(0x…)` written
// inside a screen is a local decision the theme never sees — it is not
// scaled with the text-size setting the way a role is, it does not flip
// with the dark theme, and it is invisible to the contrast guard.
//
// Measured on master 2026-09-16, presentation code and `lib/app` only
// (the PDF renderers in `domain/` print on paper at fixed sizes, and
// `lib/app/theme.dart` + `lib/core/theme/` are where colours are
// SUPPOSED to be written):
//
//   * `fontSize:`   28 in 12 files
//   * `Color(0x`    17 in 6 files
//
// The brief counted 130 and 25 over all of `lib/features` + `lib/app`.
// 100-odd of those font sizes are the PDF renderers — legitimate, and
// counting them would have made the number unmovable by screen work.
//
// ## A ratchet, the house mechanism
//
// Some of these are honest: the report designer draws a page at print
// size, and a painter's canvas has no `TextTheme`. So nothing is banned.
// The count per file may only fall, and a file that reaches zero leaves
// the map — the same shape as `state_primitives_test` and
// `_repositoryInWidgets`. `BorderRadius.circular(` went this way to zero
// and is now simply forbidden (`no_inline_border_radius_test`).
import 'package:flutter_test/flutter_test.dart';

import '../../tool/code_health_budgets.dart';

/// The budgets are `budgets.fontSize`, `.colorLiteral` and `.fontWeight` in
/// docs/design/CODE_HEALTH_BASELINE.json (#2598), written by
/// `dart run tool/code_health.dart --baseline`; they only fall. Scope:
/// presentation code and `lib/app`, not `lib/app/theme.dart`.
List<String> _failures(String category) =>
    budgetFailures(Budgets.load(), measureBudgetActuals(), only: category);

void main() {
  test('no screen grows a raw font size (#1304)', () {
    final problems = _failures('fontSize');
    expect(problems, isEmpty,
        reason: '${problems.join('\n')}\n\n'
            'Use a TextTheme role — Theme.of(context).textTheme.titleMedium '
            'and its siblings — so the size follows the reader\'s text '
            'scale and the hierarchy stays the theme\'s (#1304).');
  });

  test('no screen grows a raw colour literal (#1304)', () {
    final problems = _failures('colorLiteral');
    expect(problems, isEmpty,
        reason: '${problems.join('\n')}\n\n'
            'Use the ColorScheme or a semantic token (AppStatusColors, '
            'SeatStateColors, OfficeColors) so the colour flips with the '
            'dark theme and contrast_test can see it (#1304).');
  });

  test('no screen grows a raw font weight (#1304)', () {
    final problems = _failures('fontWeight');
    expect(problems, isEmpty,
        reason: '${problems.join('\n')}\n\n'
            'Use a role from AppTypography (sectionTitle, primaryValue…) or '
            'the named weights `.emphasised` / `.strong` '
            '(lib/core/theme/app_typography.dart, docs/ux/TYPOGRAPHY.md).');
  });
}
