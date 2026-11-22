// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4172 (B) -- the returns and corrections as a person uses them, on the
// Demo's one ledger: the movement of a delivery shows how much of it can still
// be reversed, a part goes back to its supplier from the place the goods are
// in and the figures follow, more than can be reversed is said under the field
// and moves nothing, a correction is a movement back, the page offers nothing
// to a person who only looks or when the feature is off, and no payment is
// made by it (the sheet says so). At a phone and at a desk.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_stock_reversals.dart';
import 'package:deskilo/features/stock/presentation/stock_movement_screen.dart';
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

/// The Demo's delivery of 54 mugs to the main store.
const _delivery = 'demo-stock-movement-3';

class _World {
  _World() {
    ledger = DemoStockLedger('ws-1', config);
    reversals = DemoStockReversals(ledger);
  }

  final config = DemoStockConfigCommands('ws-1');
  late final DemoStockLedger ledger;
  late final DemoStockReversals reversals;
}

const _manage = {WorkspacePermission.viewStock, WorkspacePermission.manageStock};

Future<void> _open(
  WidgetTester tester,
  _World w,
  Size size, {
  Set<WorkspacePermission> held = _manage,
  bool on = true,
  String movement = _delivery,
}) async {
  await pumpApp(
    tester,
    StockMovementScreen(movementId: movement),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(DemoStockQueries(w.ledger)),
      stockConfigCommandsProvider.overrideWithValue(w.config),
      stockReversalsProvider.overrideWithValue(w.reversals),
      myPermissionsProvider.overrideWithValue(held),
      enabledFeaturesSyncProvider.overrideWithValue({
        WorkspaceFeature.stockManagement,
        if (on) WorkspaceFeature.stockReturns,
      }),
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

Future<void> _tapOpen(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('stock-reversal-open')));
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('stock-reversal-open')));
  await _settle(tester);
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
      testWidgets('the delivery shows how much of it can still be reversed', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await tester.ensureVisible(find.byKey(const ValueKey('stock-reversals')));
        expect(find.text(_en.stockReversalRemaining('54', 'piece', '0')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-reversal-open')), findsOneWidget);
        expect(find.text(_en.stockReversalSupplierOpen), findsOneWidget);
      });

      testWidgets('a part goes back to its supplier from where the goods are, and the figures follow', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await _tapOpen(tester);
        expect(find.byKey(const ValueKey('stock-reversal-source')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-reversal-no-money')), findsOneWidget);
        await _choose(tester, 'stock-move-place', 'MAIN · Main store');
        await tester.enterText(find.byKey(const ValueKey('stock-reversal-quantity')), '4');
        await tester.tap(find.byKey(const ValueKey('stock-reversal-submit')));
        await _settle(tester);
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-main').text, '32');
        expect(w.ledger.movements.first.reason, 'return_out');
        await tester.ensureVisible(find.byKey(const ValueKey('stock-reversals')));
        expect(find.text(_en.stockReversalRemaining('50', 'piece', '4')), findsOneWidget);
        expect(find.textContaining(_en.stockReversalKindSupplier), findsOneWidget);
      });

      testWidgets('more than can be reversed is said under the field and moves nothing', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await _tapOpen(tester);
        await _choose(tester, 'stock-move-place', 'MAIN · Main store');
        await tester.enterText(find.byKey(const ValueKey('stock-reversal-quantity')), '55');
        await tester.tap(find.byKey(const ValueKey('stock-reversal-submit')));
        await _settle(tester);
        expect(find.text(_en.stockReversalMoreThanRemains('54', 'piece')), findsOneWidget);
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-main').text, '36');
      });

      testWidgets('a movement of goods that are not there is refused whole and says so', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await _tapOpen(tester);
        await _choose(tester, 'stock-move-place', 'BRANCH · Branch shop');
        await tester.enterText(find.byKey(const ValueKey('stock-reversal-quantity')), '10');
        await tester.tap(find.byKey(const ValueKey('stock-reversal-submit')));
        await _settle(tester);
        expect(find.text(_en.refusalStockNotEnough), findsOneWidget);
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-branch').text, '0');
      });

      testWidgets('a person who only looks sees what was reversed and none of the actions', (tester) async {
        final w = _World();
        await _open(tester, w, size, held: {WorkspacePermission.viewStock});
        await tester.ensureVisible(find.byKey(const ValueKey('stock-reversals')));
        expect(find.byKey(const ValueKey('stock-reversals-remaining')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-reversal-open')), findsNothing);
      });

      testWidgets('with the feature off the page offers nothing', (tester) async {
        final w = _World();
        await _open(tester, w, size, on: false);
        expect(find.byKey(const ValueKey('stock-reversals')), findsNothing);
      });

      testWidgets('the opening is not reversed here', (tester) async {
        final w = _World();
        final opening = w.ledger.movements.where((m) => m.reason == 'opening').firstOrNull;
        if (opening == null) return;
        await _open(tester, w, size, movement: opening.id);
        expect(find.byKey(const ValueKey('stock-reversals')), findsNothing);
      });
    });
  }
}
