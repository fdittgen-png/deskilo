// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4022 — the Me screens the accessibility matrix names: Home, To pay (what
// the person still owes, in My finances) and Invoices (the ones they have
// paid), each pumped over the populated state of the Me guards (two
// businesses, a booking, two currencies) at the size it is handed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/me/me_app.dart';
import '../../ux/me_screens.dart';

/// Opens [route] over the populated Me scenario at [size], then taps
/// [tabKey] when the screen has tabs to choose from.
Future<void> _pumpMe(
  WidgetTester tester,
  Size size,
  String route, {
  Key? tabKey,
}) async {
  final scenario = meScreens.first.states['populated']!();
  final router = await pumpMeApp(
    tester,
    workspace: scenario.workspace,
    accountActivity: scenario.documents,
    me: scenario.me,
    messenger: scenario.messenger,
    extraOverrides: scenario.overrides,
    size: size,
  );
  await goTo(tester, router, route);
  if (tabKey != null) {
    // The tab strip scrolls sideways: at large text a tab is off the edge.
    await tester.ensureVisible(find.byKey(tabKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(tabKey));
    await tester.pumpAndSettle();
  }
}

/// Me › Home.
Future<void> pumpMeHome(WidgetTester tester, Size size) =>
    _pumpMe(tester, size, '/me');

/// Me › To pay: My finances on what is still owed.
Future<void> pumpMeToPay(WidgetTester tester, Size size) => _pumpMe(
  tester,
  size,
  '/me/data',
  tabKey: const ValueKey('finances-tab-outstanding'),
);

/// Me › Invoices: My finances on the invoices already paid.
Future<void> pumpMeInvoices(WidgetTester tester, Size size) => _pumpMe(
  tester,
  size,
  '/me/data',
  tabKey: const ValueKey('finances-tab-paid'),
);
