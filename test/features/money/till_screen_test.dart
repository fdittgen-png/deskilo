// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 (CS4) -- the till as a cashier uses it, on the Demo's shop items and the Demo's counter: a tap rings one up and
// a second tap one more, a quantity is typed exactly (0.350), the server's pricing is what the basket shows, cash short
// of the total is refused before anything is sent, the exact amount makes the sale and the next customer starts clean,
// a country that is not ready offers nothing and says which operation, and a server refusal is said in words.
import 'package:deskilo/app/routes/till_route.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/providers/till_providers.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

/// The Demo till whose sale the server refuses with [code]: the pricing works, the tender is what is refused.
class _RefusingTill extends DemoTill {
  _RefusingTill(this.code) : super(country: 'FR', currency: 'EUR', vatPercent: 20);

  final String code;

  @override
  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders}) =>
      Future.error(PostgrestException(message: 'tender_open', code: code));
}

Future<void> _open(WidgetTester tester, TillPort till, Size size) async {
  final config = DemoStockConfigCommands('ws-1');
  await pumpApp(
    tester,
    const TillRoute(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(DemoStockQueries(DemoStockLedger('ws-1', config))),
      tillPortProvider.overrideWithValue(till),
    ],
  );
  await _settle(tester);
}

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

DemoTill _ready() => DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20);

void main() {
  for (final size in const [Size(390, 844), Size(1024, 768), Size(1440, 900)]) {
    group('the till at ${size.width.toInt()}', () {
      testWidgets('a tap rings one up, a second tap one more, and the server prices the basket', (tester) async {
        await _open(tester, _ready(), size);
        await _tap(tester, 'till-key-demo-item-milk');
        expect(find.byKey(const ValueKey('till-line-demo-item-milk')), findsOneWidget);
        expect(find.textContaining('1 l'), findsOneWidget);
        await _tap(tester, 'till-key-demo-item-milk');
        expect(find.textContaining('2 l'), findsOneWidget);
        // 2 x 2.10 gross: the total is the server's, not the till's.
        expect(find.byKey(const ValueKey('till-total')), findsOneWidget);
        expect(find.textContaining('4.20'), findsWidgets);
      });

      testWidgets('a weighed quantity is typed exactly and the line is priced again', (tester) async {
        await _open(tester, _ready(), size);
        await _tap(tester, 'till-key-demo-item-beans');
        await tester.tap(find.byKey(const ValueKey('till-line-demo-item-beans')));
        await _settle(tester);
        await tester.enterText(find.byKey(const ValueKey('till-quantity')), '0,350');
        await _tap(tester, 'till-quantity-confirm');
        expect(find.textContaining('0.35 kg'), findsOneWidget);
        // 24.00 x 0.350 = 8.40
        expect(find.textContaining('8.40'), findsWidgets);
      });

      testWidgets('a quantity that is not an exact quantity above zero is refused in words', (tester) async {
        await _open(tester, _ready(), size);
        await _tap(tester, 'till-key-demo-item-milk');
        await tester.tap(find.byKey(const ValueKey('till-line-demo-item-milk')));
        await _settle(tester);
        await tester.enterText(find.byKey(const ValueKey('till-quantity')), '0');
        await _tap(tester, 'till-quantity-confirm');
        expect(find.text(_en.tillQuantityRefused), findsOneWidget);
        expect(find.textContaining('1 l'), findsOneWidget);
      });

      testWidgets('cash short of the total is refused before anything is sent', (tester) async {
        await _open(tester, _ready(), size);
        await _tap(tester, 'till-key-demo-item-beans');
        await _tap(tester, 'till-pay');
        await tester.enterText(find.byKey(const ValueKey('till-cash-given')), '5');
        await _tap(tester, 'till-cash-confirm');
        expect(find.text(_en.tillCashShort), findsOneWidget);
        expect(find.byKey(const ValueKey('till-receipt')), findsNothing);
        expect(find.byKey(const ValueKey('till-pay')), findsOneWidget);
      });

      testWidgets('the exact amount makes the sale, change is said, and the next customer starts clean', (tester) async {
        await _open(tester, _ready(), size);
        await _tap(tester, 'till-key-demo-item-milk');
        await _tap(tester, 'till-pay');
        await tester.enterText(find.byKey(const ValueKey('till-cash-given')), '5');
        await _tap(tester, 'till-cash-confirm');
        expect(find.text(_en.tillReceiptNumber('R-00001')), findsOneWidget);
        // 5.00 given for 2.10: 2.90 back.
        expect(find.byKey(const ValueKey('till-change')), findsOneWidget);
        expect(find.textContaining('2.90'), findsOneWidget);
        await _tap(tester, 'till-next');
        expect(find.byKey(const ValueKey('till-line-demo-item-milk')), findsNothing);
        expect(find.text(_en.tillBasketEmpty), findsOneWidget);
      });

      testWidgets('a country that is not ready offers nothing and names the operation', (tester) async {
        await _open(tester, DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20, ready: false), size);
        expect(find.byKey(const ValueKey('till-not-ready')), findsOneWidget);
        expect(find.text(_en.tillNotReady('${_en.tillOpIssueReceipt}, ${_en.tillOpReconcileTender}')), findsOneWidget);
        expect(find.byKey(const ValueKey('till-key-demo-item-milk')), findsNothing);
      });

      testWidgets('a refusal of the server is said in words under the basket', (tester) async {
        await _open(tester, _RefusingTill('DKL06'), size);
        await _tap(tester, 'till-key-demo-item-milk');
        await _tap(tester, 'till-pay');
        await _tap(tester, 'till-cash-exact');
        expect(find.byKey(const ValueKey('till-problem')), findsOneWidget);
        expect(find.text(_en.refusalCounterTenders), findsOneWidget);
        expect(find.byKey(const ValueKey('till-receipt')), findsNothing);
      });
    });
  }
}
