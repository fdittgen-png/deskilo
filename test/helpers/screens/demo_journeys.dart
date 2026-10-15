// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in demo_journeys_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../demo_journey.dart';

/// Enters the app on the demonstration fixture and opens the Reserve hub,
/// which is where a visitor lands.
///
/// The widget mounted is `DeskiloRoot`, not `DeskiloApp`: the
/// demonstration bar, the Demo container and every override a visitor
/// gets come from the product's own composition (#1564).
Future<DemoJourney> pumpDemo(
  WidgetTester tester, {
  DemoPersona persona = initialDemoPersona,
  bool openHub = true,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final journey = DemoJourney.start(persona: persona);
  addTearDown(journey.dispose);
  // #2414 — at this size the device default is the menu; these journeys
  // enter through the bar's round button, so the visitor has chosen it.
  journey.fixture.prefs.navigationStyle.style = NavigationStyle.classic.wire;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: journey.root,
      child: const DeskiloRoot(),
    ),
  );
  await tester.pumpAndSettle();
  if (openHub) {
    await tester.tap(find.byType(ShellCenterButton));
    await tester.pumpAndSettle();
  }
  return journey;
}
