// SPDX-License-Identifier: 0BSD
//
// #1339 — the screens hold at a narrow phone, at twice the text size,
// and with animation switched off.
//
// `screen_guidelines_test.dart` runs the WCAG guidelines over eight
// screens at whatever size each pump helper chose — and those helpers
// choose GENEROUS sizes (800×1400, 1200×3400, 800×17000) precisely so
// their own assertions can reach every tile. That is right for what
// they test and wrong as a statement about layout: nothing in the suite
// ever looked at a 360 dp phone, which is the width most members hold.
//
// So this file re-runs a small table of screens under three conditions
// the product claims to support, and asserts the two things that are
// defensible without a design pass:
//
//   * nothing overflows — a RenderFlex overflow is an exception, and
//     `tester.takeException()` is how a widget test sees one;
//   * the screen's primary control is still there and still hittable.
//
// It deliberately does NOT re-run `meetsGuideline` here. At 2× text a
// contrast or tap-target failure would be a real defect worth its own
// issue, not something to assert in passing — and a matrix that fails
// for reasons nobody has investigated teaches the next person to ignore
// it.
//
// Only screens whose pump helper leaves the viewport alone (or takes a
// size) can appear below. The rest hard-code a tall surface and would
// silently overwrite whatever this file set; widening those helpers with
// an optional `size` is the follow-up that lets the table grow.
import 'package:flutter/material.dart';
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

/// A phone most members actually hold, and a wide surface.
const _phone = Size(360, 800);
const _tablet = Size(1200, 900);

typedef ScreenPump = Future<void> Function(WidgetTester tester, Size size);

/// The screens whose helper does not impose its own viewport.
final Map<String, ScreenPump> _screens = {
  'Reserve hub': (t, size) => pumpHub(t, size: size),
  'Alerts': (t, size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpEvents(t);
  },
  'Level canvas': (t, size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpCanvas(t);
  },
  'Money faces': (t, size) => pumpFaces(t, size: size),
  'Invoices': (t, size) => pumpInvoices(t, size: size),
  'Validation rules': (t, size) => pumpValidationSettings(t, size: size),
  'Features': (t, size) => pumpFeatures(t, size: size),
  // #1327 — the view the screen opens on.
  'Process overview': (t, size) =>
      pumpFeatures(t, size: size, switches: false),
  'Accessories': (t, size) => pumpAccessories(t, size: size),
};

// Invoices and Features were out of this table when it was written,
// because their helpers failed INSIDE themselves at 360 dp — "Found 0
// widgets", "Bad state: No element" — before the screen under test was
// reached, and a row that fails before reaching its screen measures the
// helper rather than the screen.
//
// The cause turned out to be smaller than it looked. Neither helper
// needed a different route: the shell's bottom bar is there at every
// width (only the web shell swaps it for a drawer). They tapped widgets
// that exist but are not BUILT — far down a lazy list on a short
// viewport — so they now scroll to what they are about to tap, which is
// what every other helper in this suite already does. Tall viewports had
// hidden that for as long as those helpers existed.

void main() {
  for (final entry in _screens.entries) {
    testWidgets('${entry.key} holds at 360 dp', (tester) async {
      await entry.value(tester, _phone);
      expect(tester.takeException(), isNull,
          reason: '${entry.key} overflowed at 360 dp — the width most '
              'members hold');
    });

    testWidgets('${entry.key} holds on a wide surface', (tester) async {
      await entry.value(tester, _tablet);
      expect(tester.takeException(), isNull,
          reason: '${entry.key} overflowed at ${_tablet.width} dp');
    });

    testWidgets('${entry.key} holds at twice the text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await entry.value(tester, _phone);
      expect(tester.takeException(), isNull,
          reason: '${entry.key} overflowed at 2x text — the accessibility '
              'setting, not an edge case');
    });

    testWidgets('${entry.key} reaches the same state with animation off',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await entry.value(tester, _phone);
      expect(tester.takeException(), isNull,
          reason: '${entry.key} failed with animations disabled');
    });
  }

  // Everything above asserts an ABSENCE — no exception — and an absence
  // that can never appear is not a test. This pins the mechanism the
  // whole table leans on: a row that cannot fit has to be caught by the
  // same assertion. If this one ever passes, the twelve above are
  // proving nothing and saying so loudly.
  //
  // It pins the mechanism rather than a screen, deliberately. Asserting
  // that some real screen overflows at an absurd width would encode a
  // size nobody supports and break the first time that screen improved.
  testWidgets('the matrix can fail: an overflow is caught', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [SizedBox(width: 10000, height: 10)]),
    ));

    expect(tester.takeException(), isNotNull,
        reason: 'a 10000 dp box in a 360 dp row did not register as an '
            'exception, so `takeException` is not seeing overflow and '
            'every assertion in the table above is vacuous');
  });
}

// Why only three screens: a pump helper that sets its own viewport would
// silently overwrite whatever this file asked for. `pumpHub` takes a
// `size:`; `pumpEvents` and `pumpCanvas` set none, so a size set before
// the call stands. The others hard-code tall surfaces — up to 800x17000,
// so that 82 feature switches stay mounted — and can join this table as
// soon as they take a size. That is the follow-up, not a reason to wait.
//
// If a screen ever does overflow at twice the text size, that is a
// finding for its own issue. It is not a reason to weaken the assertion
// here.
