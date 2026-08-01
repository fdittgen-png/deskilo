// SPDX-License-Identifier: 0BSD
//
// File-length budget with a ratcheting allow-list.
//
// Nobody plans a 1 500-line screen; it accretes fifty lines per feature
// until nobody can hold it. The budget makes growth VISIBLE: a file over
// it must either shed weight (extract widgets, split by concern — the
// shared-building-blocks pattern in Architecture.md exists for exactly
// this) or have its baseline raised here, in a reviewable diff, with the
// reason in the PR description. Silent accretion is the only forbidden
// path.
//
// Baseline numbers may go DOWN freely — please lower one whenever you
// shrink a file, or the coupling quietly grows back to the stale cap.
// Known hazard from the sibling project: when two branches touch the
// same baseline entry, the resolved number must be the COMBINED
// post-merge line count, not either branch's figure.

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Lines a hand-written lib/ file may have without an entry below.
const int _budget = 600;

/// Grandfathered files at their size when this ratchet landed
/// (2026-08-01), rounded up to the next 10 for edit headroom.
const Map<String, int> _baseline = {
  'lib/features/plan/presentation/screens/plan_screen.dart': 1510,
  'lib/features/workspace/presentation/screens/workspace_settings_screen.dart':
      1290,
  'lib/features/editor/presentation/screens/level_canvas_screen.dart': 1160,
  'lib/features/reservations/presentation/screens/reserve_screen.dart': 1010,
  'lib/features/profile/presentation/screens/settings_screen.dart': 980,
  'lib/features/money/presentation/screens/money_screen.dart': 980,
  'lib/features/workspace/presentation/screens/members_screen.dart': 910,
  'lib/features/members/presentation/screens/directory_screen.dart': 900,
  'lib/features/money/presentation/invoice_actions.dart': 900,
  'lib/features/workspace/domain/workspace_xml.dart': 800,
  'lib/features/reservations/presentation/widgets/week_grid.dart': 770,
  'lib/features/money/data/supabase_money_repository.dart': 750,
  'lib/features/money/presentation/widgets/bill_view.dart': 750,
  'lib/features/calendar/presentation/widgets/day_timeline.dart': 750,
  'lib/features/reservations/presentation/widgets/space_scan.dart': 730,
  'lib/features/money/domain/invoice_pdf.dart': 680,
  'lib/features/kiosk/presentation/screens/kiosk_screen.dart': 670,
  'lib/features/calendar/presentation/screens/calendar_screen.dart': 630,
};

void main() {
  test('no lib/ file outgrows its budget unnoticed', () {
    final over = <String>[];
    final stale = <String>[];

    final seen = <String>{};
    for (final file in handWrittenDartFiles('lib')) {
      seen.add(file.path);
      final count = lineCountOf(file);
      final cap = _baseline[file.path] ?? _budget;
      if (count > cap) {
        over.add('${file.path}: $count lines (cap $cap)');
      }
    }

    for (final path in _baseline.keys) {
      if (!seen.contains(path)) stale.add(path);
    }

    expect(
      over,
      isEmpty,
      reason: 'Over budget:\n${over.join('\n')}\n\n'
          'Extract widgets or split by concern first (see the shared '
          'building blocks in Architecture.md). If growth is genuinely '
          'the right call, raise this file\'s baseline in the same PR and '
          'say why in the PR description — the number changing in review '
          'IS the mechanism.',
    );
    expect(
      stale,
      isEmpty,
      reason: 'Baseline entries for files that no longer exist — delete '
          'them so the ratchet stays honest: ${stale.join(', ')}',
    );
  });
}
