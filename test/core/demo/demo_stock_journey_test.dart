// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- the Stock screen in the Demo's reference business, through the
// real routed app: the owner opens it by a link, reads exact quantities (a
// syrup received in thirds is 0.999999 litre, not one), the movements, and one
// movement at its own address; a member, who may not see the stock, is turned
// away by the link and is not offered the entry; another Demo business, which
// keeps no stock, reads as empty rather than being refused.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

final _en = AppLocalizationsEn();

Future<(DemoJourney, ProviderContainer)> _open(
  WidgetTester tester, {
  required DemoPersona persona,
  required String to,
  String space = 'pezenas',
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start(persona: persona);
  addTearDown(journey.dispose);
  journey.root
      .read(pendingDemoLinkProvider.notifier)
      .hold(DemoLink.parse({'space': space, 'persona': persona.name, 'to': to}));
  await tester.pumpWidget(
    UncontrolledProviderScope(container: journey.root, child: const DeskiloRoot()),
  );
  await tester.pumpAndSettle();
  return (journey, ProviderScope.containerOf(tester.element(find.byType(DeskiloApp))));
}

String _path(ProviderContainer c) =>
    c.read(routerProvider).routeInformationProvider.value.uri.path;

void main() {
  testWidgets('the owner reads exact quantities, the movements, and one movement at its address', (tester) async {
    final (_, container) = await _open(tester, persona: DemoPersona.owner, to: '/stock');
    expect(_path(container), '/stock');
    expect(find.text('12.5 kg'), findsOneWidget);
    expect(find.text('0.999999 l'), findsOneWidget, reason: 'three thirds of a litre, exactly');
    expect(find.text('36 piece'), findsOneWidget);

    await tester.tap(find.text(_en.stockTabMovements));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stock-movement-demo-stock-movement-7')));
    await tester.pumpAndSettle();
    expect(_path(container), '/stock/movements/demo-stock-movement-7');
    expect(find.text('0.333333 l'), findsOneWidget);
    expect(find.text('1 third'), findsOneWidget, reason: 'entered beside stored');
    expect(find.text(_en.stockCostUnknown), findsOneWidget, reason: 'the owner may see costs; this one was never recorded');
  });

  testWidgets('a movement address opens directly, and an id of nothing says so', (tester) async {
    final (_, container) = await _open(tester, persona: DemoPersona.owner, to: '/stock');
    container.read(routerProvider).go('/stock/movements/demo-stock-movement-1');
    await tester.pumpAndSettle();
    expect(_path(container), '/stock/movements/demo-stock-movement-1');
    expect(find.text('12.5 kg'), findsNWidgets(2), reason: 'stored and entered');
    container.read(routerProvider).go('/stock/movements/nothing');
    await tester.pumpAndSettle();
    expect(_path(container), '/stock/movements/nothing');
    expect(find.byKey(const ValueKey('stock-movement-none')), findsOneWidget);
  });

  testWidgets('a member who may not see the stock is turned away, whether by a link or a tap on the address', (tester) async {
    final (_, container) = await _open(tester, persona: DemoPersona.member, to: '/reserve');
    container.read(routerProvider).go('/stock');
    await tester.pumpAndSettle();
    expect(_path(container), isNot(startsWith('/stock')));
    container.read(routerProvider).go('/stock/movements/demo-stock-movement-1');
    await tester.pumpAndSettle();
    expect(_path(container), isNot(startsWith('/stock')));
    expect(find.text('12.5 kg'), findsNothing);
  });

  testWidgets('a Demo business that keeps no stock reads as empty, not refused', (tester) async {
    final (_, container) = await _open(tester, persona: DemoPersona.owner, to: '/stock', space: 'london');
    expect(_path(container), '/stock');
    expect(find.text(_en.stockEmpty), findsOneWidget);
  });

  testWidgets('a business that keeps the stock feature off has no door: the address turns even the owner away', (tester) async {
    final (_, container) = await _open(tester, persona: DemoPersona.owner, to: '/reserve', space: 'leipzig');
    container.read(routerProvider).go('/stock');
    await tester.pumpAndSettle();
    expect(_path(container), isNot(startsWith('/stock')));
  });
}
