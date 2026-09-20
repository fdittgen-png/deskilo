// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1235 — WCAG 2.2 AA as a build result, on every screen we can reach.
//
// The foundations were already here: WCAG AA contrast across three
// schemes, a touch-target guard, an IconButton-tooltip gate at zero
// baseline, and five affordance lints. What was missing was COVERAGE.
// Flutter's own `meetsGuideline` ran on two screens out of fifty-nine.
//
// Rather than edit dozens of test files, this one imports the pump
// helpers those files already export and runs the three guidelines over
// each. The marginal cost of covering a new screen is one entry in the
// table below, and a screen that regresses names itself.
//
// The three:
//   androidTapTargetGuideline  48 dp
//   iOSTapTargetGuideline      44 dp
//   labeledTapTargetGuideline  every tappable thing has a name a screen
//                              reader can say
//   textContrastGuideline      4.5:1 for body text, as rendered
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'matrix.dart';

/// #1582 — the table lives in `matrix.dart` now, with the screens that
/// are NOT measured named beside the ones that are. A generous surface
/// keeps this file measuring the guidelines rather than the fold.
const _roomy = Size(1200, 3400);

void main() {
  for (final row in matrixRowsFor(MatrixAxis.semantics)) {
    testWidgets('${row.screen} meets the accessibility guidelines',
        (tester) async {
      final handle = tester.ensureSemantics();
      await row.pump!(tester, _roomy);

      // Tap targets, on both platforms' floors.
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      // Every tappable thing has a name a screen reader can say. This is
      // the one that catches an icon-only control with no tooltip, and
      // the reason the tooltip lint holds a zero baseline.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      // Contrast AS RENDERED — the scheme-level check in
      // `test/lint/contrast_test.dart` proves the palette; this proves
      // what the screen actually painted with it.
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      handle.dispose();
    });
  }
}
