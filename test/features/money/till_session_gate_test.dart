// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- the till of a business that runs till sessions: with no till open it offers to open one instead of selling,
// with one open it sells on it (the sale goes to that till's session), and with several it asks which. Off, nothing
// changes (till_screen_test.dart).
import 'package:deskilo/app/routes/till_route.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/core/demo/data/demo_till_drawer.dart';
import 'package:deskilo/features/money/providers/till_drawer_providers.dart';
import 'package:deskilo/features/money/providers/till_providers.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester, DemoTillDrawer drawer, Size size) async {
  final config = DemoStockConfigCommands('ws-1');
  final ledger = DemoStockLedger('ws-1', config);
  await pumpApp(
    tester,
    const TillRoute(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(DemoStockQueries(ledger)),
      tillPortProvider.overrideWithValue(DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20, drawer: drawer)),
      tillDrawerPortProvider.overrideWithValue(drawer),
      tillSessionsEnabledProvider.overrideWithValue(true),
    ],
  );
  await _settle(tester);
}

void main() {
  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    group('the till with sessions at ${size.width.toInt()}', () {
      testWidgets('no open till: it offers to open one and sells nothing', (tester) async {
        await _open(tester, DemoTillDrawer(), size);
        expect(find.byKey(const ValueKey('till-open-first')), findsOneWidget);
        expect(find.byKey(const ValueKey('till-keys')), findsNothing);
      });

      testWidgets('one open till: the keys are there and a sale is made on it', (tester) async {
        final drawer = DemoTillDrawer();
        await drawer.openSession('ws-1', requestId: 'o', tillId: 'demo-till-front', floatMinor: 1000);
        await _open(tester, drawer, size);
        await tester.tap(find.byKey(const ValueKey('till-key-demo-item-milk')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('till-total')), findsOneWidget);
      });

      testWidgets('two open tills: the cashier chooses which one sells', (tester) async {
        final drawer = DemoTillDrawer();
        await drawer.openSession('ws-1', requestId: 'o1', tillId: 'demo-till-front', floatMinor: 1000);
        await drawer.openSession('ws-1', requestId: 'o2', tillId: 'demo-till-market', floatMinor: 1000);
        await _open(tester, drawer, size);
        expect(find.byKey(const ValueKey('till-choose')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('till-choose-demo-till-market')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('till-keys')), findsOneWidget);
      });
    });
  }
}
