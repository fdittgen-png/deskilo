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

  // #4421 — a screen's measures are token names: changing the spacing
  // scale or the motion durations changes every screen. Each budget is per
  // presentation library and only falls; a literal with no token of the
  // same value stays in its budget until a token is added once.
  const advice = {
    'rawInsets': 'AppSpacing (xs 4, sm 8, md 12, lg 16, xl 24) and its '
        'ready-made EdgeInsets (smAll, mdH, …)',
    'rawGap': 'a SizedBox of AppSpacing.<step>, or a named width',
    'rawDurationMs': 'MotionTokens (quick 150, standard 250, emphasized '
        '350) or AppDurations',
    'rawElevation': 'the theme\'s card and sheet elevation, or AppElevation',
    'rawAlpha': 'a ColorScheme role or a named alpha',
  };
  for (final category in advice.keys) {
    test('no screen grows a $category (#4421)', () {
      final problems = _failures(category);
      expect(problems, isEmpty,
          reason: '${problems.join('\n')}\n\nUse ${advice[category]}.');
    });
  }

  test('each raw-measure category counts its literal and not its token', () {
    const source = '''
      padding: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      padding: EdgeInsets.zero,
      padding: const EdgeInsets.only(left: 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      // padding: EdgeInsets.all(8) in a comment
      padding: const pw.EdgeInsets.only(top: 8),
      pw.SizedBox(height: 8),
      const SizedBox(height: 8),
      const SizedBox(width: AppSpacing.sm),
      SizedBox(width: 0, height: 0),
      SizedBox(height: compact ? 40 : AppSpacing.xl),
      duration: const Duration(milliseconds: 200),
      duration: MotionTokens.quick,
      elevation: 2,
      elevation: 0,
      color: c.withValues(alpha: 0.4),
      color: c.withAlpha(30),
      color: c.withValues(alpha: alphaOf(c)),
      constraints: const BoxConstraints(maxWidth: 720),
      constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
''';
    expect({
      for (final c in rawTokenPatterns.keys) c: rawTokenCountOf(c, source),
    }, {
      'rawInsets': 2,
      'rawGap': 2,
      'rawDurationMs': 1,
      'rawElevation': 1,
      'rawAlpha': 2,
      'rawMaxWidth': 1,
    });
  });
}
