// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1184 — a horizontal row of chips must say that it scrolls.
//
// Four screens ended a filter row on a chip sliced in half by the
// screen edge, and scanning for the shape found six more. A bisected
// chip reads as a rendering fault, not as "there is more this way", so
// the row needs an edge fade — `EdgeFadeScroll` — rather than a bare
// horizontal scroll view.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Horizontal scrollers that are NOT chip rows, with the reason.
const _exempt = <String, String>{
  'lib/features/calendar/presentation/widgets/day_timeline.dart':
      'a time axis, not a row of choices — it has hour labels of its own',
  'lib/features/reservations/presentation/widgets/seat_legend.dart':
      'a legend: nothing in it is tappable, so nothing is missed',
  'lib/features/reservations/presentation/widgets/week_grid.dart':
      'a grid of days with its own header row',
  'lib/features/money/presentation/widgets/report_page_designer.dart':
      'a zoomable page canvas',
  'lib/features/money/presentation/widgets/report_preview.dart':
      'a zoomable page canvas',
};

void main() {
  test('every horizontal chip row fades at the edge it continues past',
      () {
    final offenders = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      final path = file.path;
      if (_exempt.containsKey(path)) continue;
      final src = file.readAsStringSync();
      if (!src.contains('scrollDirection: Axis.horizontal')) continue;
      // Only rows of choices: a chip, a segmented button, a tab.
      final chips = RegExp(r'(Filter|Choice|Action|Input)Chip\(')
              .hasMatch(src) ||
          src.contains('SegmentedButton<');
      if (!chips) continue;
      if (!src.contains('EdgeFadeScroll')) offenders.add(path);
    }
    expect(
      offenders,
      isEmpty,
      reason: 'these files scroll a row of chips horizontally with no '
          'edge affordance, so the row ends on a chip cut in half by '
          'the screen edge. Wrap it in `EdgeFadeScroll` (or '
          '`EdgeFadeScroll.around` for a lazy list), or add the file to '
          '_exempt with the reason it is not a row of choices.',
    );
  });
}
