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
  // 1510→1530 (2026-08-02): #408 presence rule — the sheets moved to
  // check_in_sheets.dart; what remains is the admin-for-others gate and
  // its action/error handling, which need the screen's ref and context.
  'lib/features/plan/presentation/screens/plan_screen.dart': 1530,
  // 1290→1330 (2026-08-02): #395 Excel-export tile — feature lines, the
  // orchestration itself lives in excel_export.dart.
  'lib/features/workspace/presentation/screens/workspace_settings_screen.dart':
      1330,
  'lib/features/editor/presentation/screens/level_canvas_screen.dart': 1160,
  'lib/features/reservations/presentation/screens/reserve_screen.dart': 1010,
  // 980→990 (2026-08-03): #419 workspace dev-mode switch — admin gate,
  // workspace hint subtitle and the RPC write helper.
  'lib/features/profile/presentation/screens/settings_screen.dart': 990,
  'lib/features/money/presentation/screens/money_screen.dart': 980,
  // 910→950 (2026-08-04): #456 note tile + admin broadcast button —
  // the dialog itself is its own file.
  'lib/features/workspace/presentation/screens/members_screen.dart': 950,
  // 900→920 (2026-08-03): #410 admin-visible email line on the member
  // row — the row shares its chip helpers with the detail sheet, so
  // extracting it would drag half the file; 15 feature lines instead.
  // 920→960 (2026-08-04): #456 notify affordance threaded through the
  // row and the sheet.
  'lib/features/members/presentation/screens/directory_screen.dart': 960,
  // 900→920 (2026-08-01): #393 environment picker threaded through the
  // send flow — feature lines, not accretion; picker itself is its own file.
  // 920→950 (2026-08-04): #454 template lookup + resolution threaded
  // through every PDF render; the editor sheet is its own file.
  'lib/features/money/presentation/invoice_actions.dart': 950,
  'lib/features/workspace/domain/workspace_xml.dart': 800,
  // 770→780 (2026-08-04): #452 whole-level rows merge into every seat
  // row — five feature lines, not accretion.
  'lib/features/reservations/presentation/widgets/week_grid.dart': 780,
  // 750→780 (2026-08-02): #395 adds fetchWorkspaceLedger and
  // fetchPaymentIntents — two new repository surfaces, not accretion.
  // 780→800 (2026-08-04): #454 fetch/setInvoicePdfTemplate.
  'lib/features/money/data/supabase_money_repository.dart': 800,
  'lib/features/money/presentation/widgets/bill_view.dart': 750,
  'lib/features/calendar/presentation/widgets/day_timeline.dart': 750,
  'lib/features/reservations/presentation/widgets/space_scan.dart': 730,
  // 680→700 (2026-08-04): #454 owner-template intro/footer blocks.
  'lib/features/money/domain/invoice_pdf.dart': 700,
  // 670→680 (2026-08-04): #446 out-of-shell WorkHours install — the
  // kiosk arms the ambient working day itself, like realtime (#430).
  'lib/features/kiosk/presentation/screens/kiosk_screen.dart': 680,
  // 600→640 (2026-08-04): #446 fetchWorkHours/setWorkHours — two new
  // repository surfaces (merge-preserving booking_rules writes), not
  // accretion. 640→660: #456 sendMemberNote/fetchMyNotes. 660→690:
  // #458 fetch/setDefaultWorkspaceId.
  'lib/features/workspace/data/supabase_workspace_repository.dart': 690,
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
