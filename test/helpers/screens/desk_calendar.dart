// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 — the desk calendar's pump: the Demo's own composition through the
// app's builder at a desk size, on `/calendar`, and what its tests read of the
// address.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/demo_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../demo_journey.dart';

/// The Demo on `/calendar[query]` at [size].
Future<DemoJourney> pumpDeskCalendar(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  String query = '',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start();
  addTearDown(journey.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: journey.root,
      child: const DeskiloRoot(),
    ),
  );
  await tester.pumpAndSettle();
  await goTo(tester, '/calendar$query');
  return journey;
}

GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

Future<void> goTo(WidgetTester tester, String location) async {
  routerOf(tester).go(location);
  await tester.pumpAndSettle();
}

/// The address on screen.
String locationOf(WidgetTester tester) =>
    routerOf(tester).routeInformationProvider.value.uri.toString();

/// The day of the Demo's own "now" as `YYYY-MM-DD`.
String demoToday() {
  final d = demoDateOf(demoSeedNow);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// How far the scroller [key] can still go sideways.
double hScrollExtent(WidgetTester tester, Key key) => tester
    .state<ScrollableState>(
      find.descendant(of: find.byKey(key), matching: find.byType(Scrollable)),
    )
    .position
    .maxScrollExtent;
