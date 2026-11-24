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
import 'package:deskilo/core/share/text_sharer.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/providers/till_providers.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
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

/// The Demo stock whose item read is replaced: nothing to sell, or a read that fails.
class _Items extends DemoStockQueries {
  // ignore: use_super_parameters, the super parameter is private and cannot be named here
  _Items(DemoStockLedger ledger, this._items) : super(ledger);

  final Future<List<StockItem>> Function() _items;

  @override
  Future<List<StockItem>> items(String workspaceId) => _items();
}

/// A till whose sale is made but whose answer is lost the first time.
class _LostAnswer extends DemoTill {
  _LostAnswer() : super(country: 'FR', currency: 'EUR', vatPercent: 20);

  bool lost = false;

  @override
  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders}) async {
    final sold = await super.finalize(workspaceId, requestId: requestId, receiptId: receiptId, expectedRevision: expectedRevision, tenders: tenders);
    if (lost) return sold;
    lost = true;
    throw Exception('connection lost');
  }
}

/// A till whose readiness cannot be read the first time.
class _FlakyReadiness extends DemoTill {
  _FlakyReadiness() : super(country: 'FR', currency: 'EUR', vatPercent: 20);

  int reads = 0;

  @override
  Future<TillReadiness> readiness(String workspaceId) =>
      ++reads == 1 ? Future.error(const PostgrestException(message: 'down', code: '08006')) : super.readiness(workspaceId);
}

/// What the till handed to the share sheet.
final _shared = <String>[];

Future<void> _open(WidgetTester tester, TillPort till, Size size, {Future<List<StockItem>> Function()? items}) async {
  _shared.clear();
  final config = DemoStockConfigCommands('ws-1');
  final ledger = DemoStockLedger('ws-1', config);
  await pumpApp(
    tester,
    const TillRoute(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(items == null ? DemoStockQueries(ledger) : _Items(ledger, items)),
      tillPortProvider.overrideWithValue(till),
      textSharerProvider.overrideWithValue((text) async => _shared.add(text)),
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

      testWidgets('#4184 the sale made shows its frozen receipt, which is shared as the same words', (tester) async {
        await _open(tester, _ready(), size);
        await _tap(tester, 'till-key-demo-item-milk');
        await _tap(tester, 'till-pay');
        await _tap(tester, 'till-cash-exact');
        await _tap(tester, 'till-show-receipt');
        expect(find.byKey(const ValueKey('counter-receipt')), findsOneWidget);
        expect(find.textContaining(_en.tillReceiptTotal('€2.10')), findsOneWidget);
        expect(find.textContaining('Code général des impôts'), findsOneWidget);
        expect(find.byKey(const ValueKey('counter-receipt-disagrees')), findsNothing);
        await tester.ensureVisible(find.byKey(const ValueKey('counter-receipt-share')));
        await _tap(tester, 'counter-receipt-share');
        expect(_shared.single, contains(_en.tillReceiptNumber('R-00001')));
        expect(_shared.single, contains(_en.tillReceiptTotal('€2.10')));
      });

      testWidgets('#4184 the readiness shows the supported path with its specification, proof and no confirmation', (tester) async {
        await _open(tester, _ready(), size);
        await _tap(tester, 'till-readiness');
        expect(find.byKey(const ValueKey('counter-readiness-sheet')), findsOneWidget);
        expect(find.text(_en.tillReadinessCase('FR', _en.tillDeclarationNone)), findsOneWidget);
        expect(find.byKey(const ValueKey('counter-readiness-issue_receipt-supported')), findsOneWidget);
        expect(find.textContaining('pgTAP 520'), findsOneWidget);
        expect(find.text(_en.tillReadinessUnconfirmed), findsWidgets);
      });

      testWidgets('#4184 Italy is unavailable and says why, with the specification it rests on', (tester) async {
        await _open(tester, DemoTill(country: 'IT', currency: 'EUR', vatPercent: 22), size);
        expect(find.byKey(const ValueKey('till-not-ready')), findsOneWidget);
        expect(find.byKey(const ValueKey('counter-readiness-issue_receipt-unavailable')), findsOneWidget);
        expect(find.textContaining('Decreto legislativo 127/2015'), findsWidgets);
        expect(find.byKey(const ValueKey('till-key-demo-item-milk')), findsNothing);
      });

      testWidgets('#4184 a country the registry does not name supports nothing and says so', (tester) async {
        await _open(tester, DemoTill(country: 'GB', currency: 'GBP', vatPercent: 20), size);
        expect(find.text(_en.tillReadinessUnknownCountry('GB')), findsOneWidget);
        expect(find.byKey(const ValueKey('till-key-demo-item-milk')), findsNothing);
      });

      testWidgets('a sale whose answer was lost offers only to confirm it, and confirming sells once', (tester) async {
        await _open(tester, _LostAnswer(), size);
        await _tap(tester, 'till-key-demo-item-milk');
        await _tap(tester, 'till-pay');
        await _tap(tester, 'till-cash-exact');
        expect(find.byKey(const ValueKey('till-confirm')), findsOneWidget);
        expect(find.byKey(const ValueKey('till-pay')), findsNothing);
        await _tap(tester, 'till-key-demo-item-milk');
        expect(find.textContaining('1 l'), findsOneWidget, reason: 'the basket is not changed while the sale may have been made');
        await _tap(tester, 'till-confirm');
        expect(find.text(_en.tillReceiptNumber('R-00001')), findsOneWidget);
      });

      testWidgets('leaving while a sale waits asks first; staying keeps the till as it is', (tester) async {
        await _open(tester, _LostAnswer(), size);
        await _tap(tester, 'till-key-demo-item-milk');
        await _tap(tester, 'till-pay');
        await _tap(tester, 'till-cash-exact');
        expect(find.byKey(const ValueKey('till-confirm')), findsOneWidget);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(find.text(_en.tillLeaveTitle), findsOneWidget);
        await _tap(tester, 'till-leave-stay');
        expect(find.byKey(const ValueKey('till-confirm')), findsOneWidget);
      });

      testWidgets('a readiness that cannot be read says so and reads again on a tap', (tester) async {
        final till = _FlakyReadiness();
        await _open(tester, till, size);
        expect(find.byKey(const ValueKey('till-retry')), findsOneWidget);
        expect(find.byKey(const ValueKey('till-key-demo-item-milk')), findsNothing);
        await _tap(tester, 'till-retry');
        expect(find.byKey(const ValueKey('till-key-demo-item-milk')), findsOneWidget);
        expect(till.reads, 2);
      });

      testWidgets('no item to sell says so, and a failing item read is said in words', (tester) async {
        await _open(tester, _ready(), size, items: () async => const []);
        expect(find.text(_en.tillKeysEmpty), findsOneWidget);
        await _open(tester, _ready(), size, items: () => Future.error(const PostgrestException(message: 'down', code: '08006')));
        expect(find.text(_en.tillFailed), findsOneWidget);
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
