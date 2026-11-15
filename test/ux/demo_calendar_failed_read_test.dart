// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4017 — in the Demo's reference business, the events cannot be read (the
// Demo's failure switch). The visitor opens the calendar's Alerts through the
// normal navigation: the count is a mark without a number, named unknown,
// and what failed is said with Retry. Nothing reads as "nothing to decide".
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/demo_journey.dart';
import '../helpers/navigation.dart' show openAlertsTab;

void main() {
  testWidgets('the alerts that could not be read are said, never zero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final journey = DemoJourney.start();
    addTearDown(journey.dispose);
    journey.fixture.prefs.navigationStyle.style = NavigationStyle.classic.wire;
    // The switch is on before the first read, so nothing was cached.
    journey.fixture.events.failReads = true;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: journey.root,
        child: const DeskiloRoot(),
      ),
    );
    await tester.pumpAndSettle();

    await openAlertsTab(tester);

    expect(
      find.byKey(const ValueKey('calendar-alerts-unknown')),
      findsOneWidget,
      reason: 'the count is unknown, not 0',
    );
    expect(find.byKey(const ValueKey('read-failure')), findsWidgets);
  });
}
