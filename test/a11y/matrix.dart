// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1582 — the responsive / accessibility matrix, NAMED rather than
// sampled.
//
// `responsive_matrix_test.dart` and `screen_guidelines_test.dart` each
// carried their own map of screens — representative slices, and a slice
// has one property that makes it untrustworthy as evidence: a screen
// that is NOT measured is indistinguishable from a screen nobody has
// thought about. Absence reads as coverage.
//
// So the matrix is declared here, once. Every row names every axis —
// MEASURED, or one line saying why not, with the issue and the date.
// There is no third possibility: [MatrixRow] refuses to be built with
// an axis that is neither, and `matrix_coverage_test.dart` re-checks
// that from outside and ratchets the count. The axes are the six #1339
// scoped and did not deliver.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/signin_wordmark_test.dart' show pumpSignIn;
import '../features/calendar/calendar_hub_test.dart' as calendar;
import '../features/editor/level_canvas_test.dart' show pumpCanvas;
import '../features/events/events_screen_test.dart' show pumpEvents;
import '../features/events/validation_settings_screen_test.dart'
    show pumpValidationSettings;
import '../features/money/invoices_test.dart' show pumpInvoices;
import '../features/money/money_faces_test.dart' show pumpFaces;
import '../features/plan/accessories_screen_test.dart' show pumpAccessories;
import '../features/reservations/reserve_hub_test.dart' show pumpHub;
import '../features/workspace/features_screen_test.dart' show pumpFeatures;

/// The six conditions the product claims to support: 360 dp (the phone
/// most members hold), a wide web/tablet surface, twice the text size,
/// Tab traversal, Flutter's WCAG guidelines (tap targets, labels,
/// contrast as rendered), and the same final state with motion off.
enum MatrixAxis {
  narrow,
  wide,
  largeText,
  keyboard,
  semantics,
  reducedMotion,
}

/// A screen pump that honours the viewport it is handed.
typedef SizedPump = Future<void> Function(WidgetTester tester, Size size);

/// One screen and what is measured about it.
class MatrixRow {
  MatrixRow(
    this.screen, {
    this.pump,
    this.axes = const {},
    this.gaps = const {},
  }) : assert(
          MatrixAxis.values.every((a) => axes.contains(a) ^ gaps.containsKey(a)),
          '$screen: every axis is measured or carries a reason, never both '
          'and never neither',
        );

  /// The screen's name, as it appears in a failure.
  final String screen;

  /// How to build it at a given size. Null when nothing is measured.
  final SizedPump? pump;

  /// The axes asserted for this screen, and why each other one is not.
  final Set<MatrixAxis> axes;
  final Map<MatrixAxis, String> gaps;

  bool covers(MatrixAxis axis) => axes.contains(axis);
}

/// Every axis — the default for a screen whose helper honours a size.
const _all = {
  MatrixAxis.narrow,
  MatrixAxis.wide,
  MatrixAxis.largeText,
  MatrixAxis.keyboard,
  MatrixAxis.semantics,
  MatrixAxis.reducedMotion,
};

/// Nothing measured, for one stated reason.
Map<MatrixAxis, String> _unmeasured(String why) =>
    {for (final a in MatrixAxis.values) a: why};

/// Wrap a pump that sets no viewport of its own.
SizedPump _sized(Future<void> Function(WidgetTester tester) pump) =>
    (tester, size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester);
    };

/// THE MATRIX. Rows may be added; a row may not quietly lose an axis.
/// A screen that belongs here and is missing is the failure mode this
/// file exists to stop, so a row with six gaps and six reasons is a
/// better pull request than leaving the screen out.
final List<MatrixRow> kMatrix = [
  MatrixRow('Reserve hub',
      pump: (t, size) => pumpHub(t, size: size), axes: _all),
  MatrixRow('Money faces',
      pump: (t, size) => pumpFaces(t, size: size), axes: _all),
  MatrixRow('Invoices',
      pump: (t, size) => pumpInvoices(t, size: size), axes: _all),
  MatrixRow('Validation rules',
      pump: (t, size) => pumpValidationSettings(t, size: size), axes: _all),
  MatrixRow('Features',
      pump: (t, size) => pumpFeatures(t, size: size), axes: _all),
  // #1327 — the view the screen opens on.
  MatrixRow('Process overview',
      pump: (t, size) => pumpFeatures(t, size: size, switches: false),
      axes: _all),
  MatrixRow('Accessories',
      pump: (t, size) => pumpAccessories(t, size: size), axes: _all),
  MatrixRow('Alerts', pump: _sized(pumpEvents), axes: _all),
  // #1582 — two screens the slice never named. Both helpers already
  // take a size; nothing but the list was missing.
  MatrixRow('Sign in',
      pump: (t, size) => pumpSignIn(t, size: size), axes: _all),
  // The calendar hub drives the shell, so its row exercises SHARED
  // surfaces the route passes through rather than the calendar. It
  // opened with three gaps, and #1583 closed them: two of the three
  // named surfaces could be handed less width than they need (the help
  // hint's tip chevrons, the reserve view menu's label) and the canvas
  // scrollbar asserted on a negative track, all three now fixed — and
  // `pumpHub` was reading `size` as PHYSICAL pixels at a ratio of 3,
  // so this row had been measuring 120 dp, not the 360 it names.
  MatrixRow('Calendar hub',
      pump: (t, size) => calendar.pumpHub(t, size: size), axes: _all),
  MatrixRow('Level canvas',
      pump: _sized(pumpCanvas),
      axes: const {
        MatrixAxis.narrow,
        MatrixAxis.wide,
        MatrixAxis.largeText,
        MatrixAxis.semantics,
        MatrixAxis.reducedMotion,
      },
      gaps: const {
        MatrixAxis.keyboard: 'the canvas is a painter with no focusable '
            'control of its own; keyboard placement is #1582 follow-up '
            '(2026-09-20)',
      }),
  // NOT measured. Their helpers hard-code a tall viewport so their own
  // assertions reach every tile, and a size set before the call is
  // silently overwritten — a row that measures the HELPER instead of
  // the screen is worse than no row. Widening each helper with an
  // optional `size:` is one line, and the only reason it has not
  // happened is that nobody could see the hole.
  MatrixRow('Members',
      gaps: _unmeasured(
          'pumpMembersWith hard-codes 800x2200 — #1582 (2026-09-20)')),
  MatrixRow('Settings',
      gaps: _unmeasured(
          'pumpSettingsAs hard-codes 800x3600 — #1582 (2026-09-20)')),
  MatrixRow('Workspace settings',
      gaps: _unmeasured(
          'pumpWorkspaceSettings hard-codes 800x3200 — #1582 (2026-09-20)')),
  MatrixRow('Member directory',
      gaps: _unmeasured('pumpDirectory takes no size and needs a seeded '
          'repository per case — #1582 (2026-09-20)')),
];

/// Rows whose [axis] is asserted somewhere in this folder.
Iterable<MatrixRow> matrixRowsFor(MatrixAxis axis) =>
    kMatrix.where((row) => row.covers(axis));
