// SPDX-License-Identifier: AGPL-3.0-or-later
// #3070: the real purchases menu opens Demo payables and the supplier alias.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/features/money/presentation/screens/suppliers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/demo_journey.dart';

void main() {
  testWidgets('Demo owner opens payables from purchases and the supplier alias', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final journey = DemoJourney.start();
    addTearDown(journey.dispose);
    journey.fixture.prefs.navigationStyle.style = 'menu';
    journey.root.read(pendingDemoLinkProvider.notifier).hold(DemoLink.parse({
      'space': 'pezenas', 'persona': 'owner', 'to': '/reserve',
    }));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: journey.root,
      child: const DeskiloRoot(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    final door = find.byKey(const ValueKey('drawer-purchases-to-pay'));
    if (door.evaluate().isEmpty) {
      await tester.tap(find.text('Purchases & suppliers'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(door);
    await tester.tap(door);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payable-demo-payable-demo-bill-cleaning')), findsOneWidget);
    expect(find.textContaining('44.00'), findsWidgets);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/suppliers');
    await tester.pumpAndSettle();
    expect(find.byType(SuppliersScreen), findsOneWidget);
    expect(GoRouter.of(tester.element(find.byType(SuppliersScreen))).routeInformationProvider.value.uri.path, '/money/suppliers');
  });
}
