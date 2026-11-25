// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4170 (B) -- the Transfers page as a person uses it, on the Demo's one
// ledger: the load that is on its way is visible, received in part it leaves
// the rest on the way, goods moved inside a site move at once and between
// sites are loaded onto the way, less on hand than asked refuses the whole
// command and says so under the sheet, taking goods out is offered only when
// its feature is on, and a person who may only look runs nothing.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_operations.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/features/stock/presentation/stock_transfers_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

class _World {
  _World() {
    ledger = DemoStockLedger('ws-1', config);
    operations = DemoStockOperations(ledger);
  }

  final config = DemoStockConfigCommands('ws-1');
  late final DemoStockLedger ledger;
  late final DemoStockOperations operations;
}

const _manage = {WorkspacePermission.viewStock, WorkspacePermission.manageStock};

Future<void> _open(
  WidgetTester tester,
  _World w,
  Size size, {
  Set<WorkspacePermission> held = _manage,
  bool takeOut = false,
  AppFormat? format,
}) async {
  await pumpApp(
    tester,
    const StockTransfersScreen(),
    size: size,
    overrides: [
      // a test that pins its own format replaces the standard one
      ...standardTestOverrides(pinFormats: format == null),
      if (format != null) ...[appFormatProvider.overrideWithValue(format), personalFormatProvider.overrideWithValue(format)],
      stockQueriesProvider.overrideWithValue(DemoStockQueries(w.ledger)),
      stockConfigCommandsProvider.overrideWithValue(w.config),
      stockOperationsProvider.overrideWithValue(w.operations),
      myPermissionsProvider.overrideWithValue(held),
      enabledFeaturesSyncProvider.overrideWithValue({
        WorkspaceFeature.stockManagement,
        if (takeOut) WorkspaceFeature.stockTakeOut,
      }),
    ],
  );
  await _settle(tester);
}

/// Two frames and a transition: what a sheet or a menu needs to arrive.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _choose(WidgetTester tester, String key, String text) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
  await tester.tap(find.text(text).last);
  await _settle(tester);
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('the load that is on its way is visible, with what it still holds', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        expect(find.byKey(const ValueKey('stock-transfer-demo-transfer-1')), findsOneWidget);
        expect(find.text(_en.stockTransferRoute('MAIN', 'BRANCH')), findsOneWidget);
        expect(find.text(_en.stockTransferLine('Mugs', '6', 'piece', '6')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('stock-transfer-status-demo-transfer-1')),
            matching: find.text(_en.stockTransfersOnTheWay),
          ),
          findsOneWidget,
        );
      });

      testWidgets('received in part, the rest stays on the way and the figures follow', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await tester.tap(find.byKey(const ValueKey('stock-transfer-receive-demo-transfer-1')));
        await _settle(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-receive-demo-transfer-line-1')), '2');
        await tester.tap(find.byKey(const ValueKey('stock-receive-submit')));
        await _settle(tester);
        expect(find.text(_en.stockTransferLine('Mugs', '4', 'piece', '6')), findsOneWidget);
        expect(find.text(_en.stockTransferStatusPartly), findsOneWidget);
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-transit').text, '4');
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-branch').text, '2');
      });

      testWidgets('more than is on the way cannot be received: said under the field, nothing moves', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await tester.tap(find.byKey(const ValueKey('stock-transfer-receive-demo-transfer-1')));
        await _settle(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-receive-demo-transfer-line-1')), '7');
        await tester.tap(find.byKey(const ValueKey('stock-receive-submit')));
        await _settle(tester);
        expect(find.text(_en.stockReasonReceiveOver), findsOneWidget);
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-transit').text, '6');
      });

      testWidgets('inside one site the goods move at once; between sites they are loaded onto the way', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await tester.tap(find.byKey(const ValueKey('stock-move-open')));
        await _settle(tester);
        await _choose(tester, 'stock-move-item', 'Mugs');
        await _choose(tester, 'stock-move-from', 'MAIN · Main store');
        await _choose(tester, 'stock-move-to', 'MAIN-SHELF-A · Shelf A');
        expect(find.byKey(const ValueKey('stock-move-same-site')), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('stock-move-quantity')), '3');
        await tester.tap(find.byKey(const ValueKey('stock-move-submit')));
        await _settle(tester);
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-main').text, '33');
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-shelf').text, '13', reason: '12 on the shelf less the 2 sold, and the 3 that moved');

        await tester.tap(find.byKey(const ValueKey('stock-move-open')));
        await _settle(tester);
        await _choose(tester, 'stock-move-item', 'Mugs');
        await _choose(tester, 'stock-move-from', 'MAIN · Main store');
        await _choose(tester, 'stock-move-to', 'BRANCH · Branch shop');
        expect(find.byKey(const ValueKey('stock-move-other-site')), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('stock-move-quantity')), '5');
        await tester.tap(find.byKey(const ValueKey('stock-move-submit')));
        await _settle(tester);
        expect(w.ledger.openTransfers.length, 2, reason: 'the seeded load and the new one');
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-transit').text, '11');
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-main').text, '28');
      });

      testWidgets('less on hand than asked refuses the whole command and says so under the sheet', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await tester.tap(find.byKey(const ValueKey('stock-move-open')));
        await _settle(tester);
        await _choose(tester, 'stock-move-item', 'Mugs');
        await _choose(tester, 'stock-move-from', 'MAIN-SHELF-A · Shelf A');
        await _choose(tester, 'stock-move-to', 'MAIN · Main store');
        await tester.enterText(find.byKey(const ValueKey('stock-move-quantity')), '500');
        await tester.tap(find.byKey(const ValueKey('stock-move-submit')));
        await _settle(tester);
        expect(find.text(_en.refusalStockNotEnough), findsOneWidget);
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-shelf').text, '10', reason: 'nothing moved: the 12 shelved less the 2 sold');
      });

      testWidgets('a mistake is said under its field before anything is sent', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await tester.tap(find.byKey(const ValueKey('stock-move-open')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-move-submit')));
        await _settle(tester);
        // #4402 -- a missing choice is the app's own check, in words of its own
        expect(find.text(_en.stockRequiredItem), findsOneWidget);
        expect(find.text(_en.stockReasonQuantityInvalid), findsOneWidget);
        expect(w.ledger.openTransfers.length, 1);
      });

      testWidgets('taking goods out is offered only when its feature is on, and loses what was taken', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        expect(find.byKey(const ValueKey('stock-takeout-open')), findsNothing);

        await _open(tester, w, size, takeOut: true);
        await tester.tap(find.byKey(const ValueKey('stock-takeout-open')));
        await _settle(tester);
        await tester.tap(find.text(_en.stockTakeOutLoss));
        await _settle(tester);
        await _choose(tester, 'stock-move-item', 'Coffee beans');
        await _choose(tester, 'stock-move-from', 'MAIN · Main store');
        await tester.enterText(find.byKey(const ValueKey('stock-move-quantity')), '0.5');
        await tester.tap(find.byKey(const ValueKey('stock-move-submit')));
        await _settle(tester);
        expect(w.ledger.balance('demo-item-beans', 'demo-place-main').text, '12');
        expect(w.ledger.movements.first.reason, 'loss');
      });

      testWidgets('in French, half a kilo typed as 0,5 is taken out exactly', (tester) async {
        final w = _World();
        await _open(tester, w, size, takeOut: true, format: const AppFormat(locale: 'fr_FR', currencyCode: 'EUR'));
        await tester.tap(find.byKey(const ValueKey('stock-takeout-open')));
        await _settle(tester);
        await tester.tap(find.text(_en.stockTakeOutLoss));
        await _settle(tester);
        await _choose(tester, 'stock-move-item', 'Coffee beans');
        await _choose(tester, 'stock-move-from', 'MAIN · Main store');
        await tester.enterText(find.byKey(const ValueKey('stock-move-quantity')), '0,5');
        await tester.tap(find.byKey(const ValueKey('stock-move-submit')));
        await _settle(tester);
        expect(w.ledger.balance('demo-item-beans', 'demo-place-main').text, '12');
      });

      testWidgets('a person who may only look sees the transfers and runs nothing', (tester) async {
        final w = _World();
        await _open(tester, w, size, held: {WorkspacePermission.viewStock}, takeOut: true);
        expect(find.byKey(const ValueKey('stock-transfer-demo-transfer-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-move-open')), findsNothing);
        expect(find.byKey(const ValueKey('stock-takeout-open')), findsNothing);
        expect(find.byKey(const ValueKey('stock-transfer-receive-demo-transfer-1')), findsNothing);
      });
    });
  }
}
