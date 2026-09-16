// SPDX-License-Identifier: 0BSD
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

import 'lint_sources.dart';

/// Presentation files still writing a raw font size → how many.
const Map<String, int> _fontSizeBaseline = {
  'lib/features/calendar/presentation/widgets/day_timeline.dart': 1,
  'lib/features/money/presentation/widgets/invoice_template_sheet.dart': 1,
  'lib/features/money/presentation/widgets/report_field_picker.dart': 1,
  'lib/features/money/presentation/widgets/report_layout_preview.dart': 2,
  'lib/features/money/presentation/widgets/report_page_designer.dart': 1,
  'lib/features/money/presentation/widgets/report_page_style.dart': 5,
  'lib/features/money/presentation/widgets/report_preview.dart': 1,
  'lib/features/money/presentation/widgets/report_visual_editor.dart': 9,
  'lib/features/plan/presentation/widgets/floor_plan_painter.dart': 2,
  'lib/features/plan/presentation/widgets/plan_paint_helpers.dart': 3,
  'lib/features/profile/presentation/widgets/member_avatar.dart': 1,
  'lib/features/reservations/presentation/widgets/month_grid.dart': 1,
};

/// Presentation files still writing a raw colour literal → how many.
const Map<String, int> _colorBaseline = {
  'lib/features/calendar/presentation/screens/calendar_screen.dart': 8,
  'lib/features/money/presentation/widgets/report_page_designer.dart': 1,
  'lib/features/money/presentation/widgets/report_page_style.dart': 5,
  'lib/features/money/presentation/widgets/report_preview.dart': 1,
  'lib/features/plan/presentation/widgets/plan_paint_helpers.dart': 1,
  'lib/features/workspace/presentation/widgets/note_check.dart': 1,
};

bool _inScope(String path) =>
    path != 'lib/app/theme.dart' &&
    (path.contains('/presentation/') || path.startsWith('lib/app/'));

/// Compares the live count of [needle] per file against [baseline].
List<String> ratchet(Map<String, int> live, Map<String, int> baseline) {
  final problems = <String>[];
  for (final e in live.entries) {
    final allowed = baseline[e.key] ?? 0;
    if (e.value > allowed) {
      problems.add('${e.key}: ${e.value}, baseline $allowed — grew');
    } else if (e.value < allowed) {
      problems.add('${e.key}: ${e.value}, baseline $allowed — lower the '
          'baseline in the same commit');
    }
  }
  for (final path in baseline.keys) {
    if (!live.containsKey(path)) {
      problems.add('$path: none left — delete it from the baseline');
    }
  }
  return problems;
}

Map<String, int> _count(String needle) {
  final out = <String, int>{};
  for (final file in handWrittenDartFiles('lib')) {
    if (!_inScope(file.path)) continue;
    final n = needle.allMatches(file.readAsStringSync()).length;
    if (n > 0) out[file.path] = n;
  }
  return out;
}

void main() {
  test('no screen grows a raw font size (#1304)', () {
    final problems = ratchet(_count('fontSize:'), _fontSizeBaseline);
    expect(problems, isEmpty,
        reason: '${problems.join('\n')}\n\n'
            'Use a TextTheme role — Theme.of(context).textTheme.titleMedium '
            'and its siblings — so the size follows the reader\'s text '
            'scale and the hierarchy stays the theme\'s (#1304).');
  });

  test('no screen grows a raw colour literal (#1304)', () {
    final problems = ratchet(_count('Color(0x'), _colorBaseline);
    expect(problems, isEmpty,
        reason: '${problems.join('\n')}\n\n'
            'Use the ColorScheme or a semantic token (AppStatusColors, '
            'SeatStateColors, OfficeColors) so the colour flips with the '
            'dark theme and contrast_test can see it (#1304).');
  });

  group('the ratchet can fail', () {
    test('growth, shrinkage and a file gone are all reported', () {
      expect(ratchet({'a.dart': 2}, {'a.dart': 1}).single, contains('grew'));
      expect(ratchet({'a.dart': 1}, {'a.dart': 2}).single,
          contains('lower the baseline'));
      expect(ratchet({}, {'a.dart': 1}).single, contains('delete it'));
      expect(ratchet({'new.dart': 1}, {}).single, contains('grew'));
      expect(ratchet({'a.dart': 1}, {'a.dart': 1}), isEmpty);
    });
  });
}
