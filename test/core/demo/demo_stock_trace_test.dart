// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4173 -- the Demo's goods trace and stock value, through the real routed app: the owner reads the
// operational value (a known total, "not complete" because the mugs have no known cost, and the mugs
// listed outside the total); a delivery of an order put away is a movement whose page traces back to
// that order; a movement with no purchase behind it says "not linked". A member who may not see what
// goods cost is turned away from the value page by its link.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/stock/domain/stock_receiving.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

final _en = AppLocalizationsEn();

Future<ProviderContainer> _open(WidgetTester tester, {required DemoPersona persona, required String to}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start(persona: persona);
  addTearDown(journey.dispose);
  journey.root.read(pendingDemoLinkProvider.notifier).hold(DemoLink.parse({'space': 'pezenas', 'persona': persona.name, 'to': to}));
  await tester.pumpWidget(UncontrolledProviderScope(container: journey.root, child: const DeskiloRoot()));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
}

String _path(ProviderContainer c) => c.read(routerProvider).routeInformationProvider.value.uri.path;

void main() {
  testWidgets('the owner reads the stock value: known costs totalled, not complete, the mugs outside it', (tester) async {
    final container = await _open(tester, persona: DemoPersona.owner, to: '/stock');
    container.read(routerProvider).go('/stock/value');
    await tester.pumpAndSettle();
    expect(_path(container), '/stock/value');
    expect(find.byKey(const ValueKey('stock-value-total')), findsOneWidget);
    expect(find.byKey(const ValueKey('stock-value-incomplete')), findsOneWidget, reason: 'the mugs have no known cost');
    expect(find.byKey(const ValueKey('stock-value-uncosted-demo-item-mugs-')), findsOneWidget);
    expect(find.text(_en.stockValueBasis), findsOneWidget);
  });

  testWidgets('a delivery put away traces back to its order; a movement with no purchase says not linked', (tester) async {
    final container = await _open(tester, persona: DemoPersona.owner, to: '/reserve');
    final config = container.read(stockConfigCommandsProvider);
    final places = {for (final p in await config.places(demoFirstSpaceId)) p.code: p.id};
    final done = await container.read(stockReceivingCommandsProvider).putAway(demoFirstSpaceId, 'demo-receipt-3', [
      PutAwayAllocation(lineNo: 1, quantity: '20', locationId: places['MAIN']!),
    ], 'req-trace');
    final movement = done.allocations.single.movementId;
    container.read(routerProvider).go('/stock/movements/$movement');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-order')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('stock-trace-order')), findsOneWidget, reason: 'traced to the order it was delivered on');
    expect(find.byKey(const ValueKey('stock-trace-no-bill')), findsOneWidget, reason: 'no bill is linked to it in the Demo');

    container.read(routerProvider).go('/stock/movements/demo-stock-movement-7');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-not-linked')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('stock-trace-not-linked')), findsOneWidget);
  });

  testWidgets('a member who may not see what goods cost is turned away from the value page', (tester) async {
    final container = await _open(tester, persona: DemoPersona.member, to: '/reserve');
    container.read(routerProvider).go('/stock/value');
    await tester.pumpAndSettle();
    expect(_path(container), isNot('/stock/value'));
    expect(find.byKey(const ValueKey('stock-value-total')), findsNothing);
  });
}
