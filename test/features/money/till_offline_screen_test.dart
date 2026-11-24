// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 (CS11) -- the till when the connection is lost, as a cashier sees it at 390 and 1440: the till says it is offline and cash only,
// goes on selling from the prices it held, shows the receipt as recorded offline with its number on the till (no receipt number, not
// signed), and when the connection returns sends the sales and says what the server answered; a send the server refuses because the
// session was closed says the sales stay for a manager, and offline data that cannot be read stops offline selling until a manager
// drops it after a warning.
import 'package:deskilo/app/routes/till_route.dart';
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/core/demo/data/demo_till_drawer.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/till_offline.dart';
import 'package:deskilo/features/money/domain/till_offline_queue.dart';
import 'package:deskilo/features/money/providers/money_providers.dart' show servicesProvider;
import 'package:deskilo/features/money/providers/till_drawer_providers.dart';
import 'package:deskilo/features/money/providers/till_providers.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

class _Mem implements OfflineStore {
  _Mem([this.text]);
  String? text;
  @override
  Future<String?> read() async => text;
  @override
  Future<void> write(String json) async => text = json;
  @override
  Future<void> wipe() async => text = null;
}

/// A server that refuses the whole send, as it does for a session closed meanwhile.
class _ClosedSession implements TillOfflinePort {
  @override
  Future<OfflineSyncAnswer> sync(String workspaceId, {required String sessionId, required DateTime offlineSince, required List<OfflineSale> sales, required int minorDigits}) =>
      throw const PostgrestException(message: 'open the till first', code: DkCode.dkl12);

  @override
  Future<OfflineList> list(String workspaceId, {required String sessionId}) async => const OfflineList(sales: [], gaps: []);
}

final _en = AppLocalizationsEn();

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
}

Future<DemoTill> _open(WidgetTester tester, Size size, {_Mem? store, TillOfflinePort? offlinePort}) async {
  final drawer = DemoTillDrawer();
  await drawer.openSession('ws-1', requestId: 'o', tillId: 'demo-till-front', floatMinor: 1000);
  final till = DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20, drawer: drawer);
  final config = DemoStockConfigCommands('ws-1');
  final ledger = DemoStockLedger('ws-1', config);
  final memory = store ?? _Mem();
  await pumpApp(
    tester,
    const TillRoute(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(DemoStockQueries(ledger)),
      servicesProvider.overrideWith((ref) async => [const ServiceItem(id: 'demo-item-milk', workspaceId: 'ws-1', name: 'Milk', priceCents: 210, active: true)]),
      tillPortProvider.overrideWithValue(till),
      tillOfflinePortProvider.overrideWithValue(offlinePort ?? till),
      tillDrawerPortProvider.overrideWithValue(drawer),
      tillSessionsEnabledProvider.overrideWithValue(true),
      tillOfflineEnabledProvider.overrideWithValue(true),
      tillOfflineStoreFactoryProvider.overrideWithValue((_) => memory),
    ],
  );
  await _settle(tester);
  return till;
}

Future<void> _sellOffline(WidgetTester tester) async {
  await _tap(tester, 'till-key-demo-item-milk');
  await _tap(tester, 'till-pay');
  await tester.enterText(find.byKey(const ValueKey('till-cash-given')), '5');
  await _tap(tester, 'till-cash-confirm');
}

void main() {
  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    group('the till offline at ${size.width.toInt()}', () {
      testWidgets('online there is no offline banner', (tester) async {
        await _open(tester, size);
        await _tap(tester, 'till-key-demo-item-milk');
        expect(find.byKey(const ValueKey('till-offline-banner')), findsNothing);
        expect(find.byKey(const ValueKey('till-total')), findsOneWidget);
      });

      testWidgets('when the line is lost the till says offline and cash only, and sells from the prices it held', (tester) async {
        final till = await _open(tester, size);
        till.connected = false;
        await _tap(tester, 'till-key-demo-item-milk');
        expect(find.byKey(const ValueKey('till-offline-banner')), findsOneWidget);
        expect(find.text(_en.tillOfflineBanner), findsOneWidget);
        expect(find.byKey(const ValueKey('till-total')), findsOneWidget);
        await _tap(tester, 'till-pay');
        await tester.enterText(find.byKey(const ValueKey('till-cash-given')), '5');
        await _tap(tester, 'till-cash-confirm');
        expect(find.byKey(const ValueKey('till-offline-receipt')), findsOneWidget);
        expect(find.text(_en.tillOfflineRecorded(1)), findsOneWidget);
        expect(find.byKey(const ValueKey('till-offline-not-signed')), findsOneWidget);
        expect(find.byKey(const ValueKey('till-receipt')), findsNothing, reason: 'an offline sale has no receipt number yet');
        expect(find.byKey(const ValueKey('till-change')), findsOneWidget);
        await _tap(tester, 'till-next');
        expect(find.text(_en.tillOfflineWaiting(1)), findsOneWidget);
      });

      testWidgets('when the connection returns the sales are sent and the answer is said', (tester) async {
        final till = await _open(tester, size);
        till.connected = false;
        await _sellOffline(tester);
        await _tap(tester, 'till-next');
        till.connected = true;
        await _tap(tester, 'till-offline-send');
        expect(find.byKey(const ValueKey('till-offline-report')), findsOneWidget);
        expect(find.text(_en.tillOfflineReportAccepted(1)), findsOneWidget);
        await _tap(tester, 'till-offline-report-ok');
        expect(find.byKey(const ValueKey('till-offline-banner')), findsNothing);
      });

      testWidgets('a send refused because the session was closed says the sales stay for a manager', (tester) async {
        final till = await _open(tester, size, offlinePort: _ClosedSession());
        till.connected = false;
        await _sellOffline(tester);
        await _tap(tester, 'till-next');
        till.connected = true;
        await _tap(tester, 'till-offline-send');
        expect(find.text(_en.tillOfflineClosedSession), findsOneWidget);
        expect(find.text(_en.tillOfflineKept(1)), findsOneWidget);
        await _tap(tester, 'till-offline-report-ok');
        expect(find.text(_en.tillOfflineWaiting(1)), findsOneWidget, reason: 'the sale is still on the device');
      });

      testWidgets('offline data that cannot be read stops offline selling until it is dropped after a warning', (tester) async {
        final store = _Mem('not our data');
        await _open(tester, size, store: store);
        expect(find.byKey(const ValueKey('till-offline-unreadable')), findsOneWidget);
        await _tap(tester, 'till-offline-discard');
        expect(find.byKey(const ValueKey('till-offline-discard-confirm')), findsOneWidget);
        await _tap(tester, 'till-offline-discard-cancel');
        expect(store.text, 'not our data');
        await _tap(tester, 'till-offline-discard');
        await _tap(tester, 'till-offline-discard-confirm');
        expect(find.byKey(const ValueKey('till-offline-unreadable')), findsNothing);
        expect(store.text, isNull);
      });
    });
  }
}
