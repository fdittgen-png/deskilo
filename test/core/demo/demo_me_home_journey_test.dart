// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3281 — the Demo journey of the personal home: a member who owes a bill
// opens Me, meets To pay, follows it to My finances, and comes back to Me
// where they left it. Real screens, real Demo fixture, real composition.
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Me -> To pay -> My finances -> back to Me, context unchanged', (
    tester,
  ) async {
    await pumpDemo(tester, persona: DemoPersona.member, openHub: false);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first))
      ..go('/me');
    final glance = find.byKey(const ValueKey('me-home-tab-finance-glance-owed'));
    await _until(tester, glance);
    expect(glance, findsOneWidget, reason: 'Bruno owes a bill in the Demo');

    // The card's left edge: the amounts keep their own reveal targets.
    await tester.tapAt(tester.getTopLeft(glance) + const Offset(12, 12));
    await _until(tester, find.byKey(const ValueKey('finances-tabs')));
    expect(find.byKey(const ValueKey('finances-tabs')), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters,
      isNot(contains('workspace')),
      reason: 'the personal action does not silently filter to one space',
    );

    router.go('/me');
    await _until(tester, glance);
    expect(glance, findsOneWidget, reason: 'back on Me, the card is still there');
    expect(router.routeInformationProvider.value.uri.path, '/me');
  });
}
