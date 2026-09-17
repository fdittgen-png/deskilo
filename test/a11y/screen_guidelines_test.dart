// SPDX-License-Identifier: 0BSD
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
import 'package:flutter_test/flutter_test.dart';

import '../features/editor/level_canvas_test.dart' show pumpCanvas;
import '../features/events/events_screen_test.dart' show pumpEvents;
import '../features/events/validation_settings_screen_test.dart'
    show pumpValidationSettings;
import '../features/money/invoices_test.dart' show pumpInvoices;
import '../features/money/money_faces_test.dart' show pumpFaces;
import '../features/plan/accessories_screen_test.dart' show pumpAccessories;
import '../features/reservations/reserve_hub_test.dart' show pumpHub;
import '../features/workspace/features_screen_test.dart' show pumpFeatures;

typedef ScreenPump = Future<void> Function(WidgetTester tester);

/// The screens this runs over. Adding one is a line.
final Map<String, ScreenPump> _screens = {
  'Reserve hub': (t) => pumpHub(t),
  'Money faces': (t) => pumpFaces(t),
  'Invoices': (t) => pumpInvoices(t),
  'Alerts': (t) => pumpEvents(t),
  'Validation rules': (t) => pumpValidationSettings(t),
  'Features': (t) => pumpFeatures(t),
  // #1327 — the view the screen opens on.
  'Process overview': (t) => pumpFeatures(t, switches: false),
  'Accessories': (t) => pumpAccessories(t),
  'Level canvas': (t) => pumpCanvas(t),
};

void main() {
  for (final entry in _screens.entries) {
    testWidgets('${entry.key} meets the accessibility guidelines',
        (tester) async {
      final handle = tester.ensureSemantics();
      await entry.value(tester);

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
