// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4172 (B) -- the counts as a person uses them, on the Demo's one ledger:
// recording a count moves nothing and shows it waiting for approval; whoever
// may approve applies it and exactly its difference moves; a count the stock
// has moved since says it must be counted again and offers no apply; a person
// who cannot approve sees it waiting and has no apply; a person who only looks
// cannot count. At a phone and at a desk.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_stock_reversals.dart';
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/features/stock/domain/stock_reversals.dart';
import 'package:deskilo/features/stock/presentation/stock_counts_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

class _World {
  _World() {
    ledger = DemoStockLedger('ws-1', config);
    reversals = DemoStockReversals(ledger);
  }

  final config = DemoStockConfigCommands('ws-1');
  late final DemoStockLedger ledger;
  late final DemoStockReversals reversals;
}

const _count = {WorkspacePermission.viewStock, WorkspacePermission.manageStock};
const _approve = {...{WorkspacePermission.viewStock, WorkspacePermission.manageStock}, WorkspacePermission.approveStockAdjustments};

Future<void> _open(WidgetTester tester, _World w, Size size, {Set<WorkspacePermission> held = _approve, AppFormat? format}) async {
  await pumpApp(
    tester,
    const StockCountsScreen(),
    size: size,
    overrides: [
      // a test that pins its own format replaces the standard one
      ...standardTestOverrides(pinFormats: format == null),
      if (format != null) ...[appFormatProvider.overrideWithValue(format), personalFormatProvider.overrideWithValue(format)],
      stockQueriesProvider.overrideWithValue(DemoStockQueries(w.ledger)),
      stockConfigCommandsProvider.overrideWithValue(w.config),
      stockReversalsProvider.overrideWithValue(w.reversals),
      myPermissionsProvider.overrideWithValue(held),
      enabledFeaturesSyncProvider.overrideWithValue({WorkspaceFeature.stockManagement, WorkspaceFeature.stockCounts}),
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

Future<void> _choose(WidgetTester tester, String key, String text) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
  await tester.tap(find.text(text).last);
  await _settle(tester);
}

/// Counts the beans at the main store.
Future<void> _recordCount(WidgetTester tester, String observed) async {
  await tester.tap(find.byKey(const ValueKey('stock-count-open')));
  await _settle(tester);
  await _choose(tester, 'stock-move-item', 'Coffee beans');
  await _choose(tester, 'stock-move-place', 'MAIN · Main store');
  await tester.enterText(find.byKey(const ValueKey('stock-count-observed')), observed);
  await tester.tap(find.byKey(const ValueKey('stock-count-submit')));
  await _settle(tester);
}

StockCountDraft _draft(String observed, String request) => (
  countId: 'c-1',
  itemId: 'demo-item-beans',
  locationId: 'demo-place-main',
  observed: observed,
  requestId: request,
  variantId: null,
  lotId: null,
  reason: '',
);

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      // #4424 -- the quantities read in the member's format: 12,5 kg in French
      testWidgets('a French format shows what the book held as 12,5 kg', (tester) async {
        final w = _World();
        await _open(tester, w, size, format: const AppFormat(locale: 'fr_FR', currencyCode: 'EUR'));
        await _recordCount(tester, '10');
        expect(find.textContaining('12,5 kg'), findsOneWidget);
        expect(find.textContaining('12.5 kg'), findsNothing);
      });

      testWidgets('a count moves nothing and waits for its approval, visibly', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        expect(find.byKey(const ValueKey('stock-counts-empty')), findsOneWidget);
        await _recordCount(tester, '10');
        expect(find.text(_en.stockCountsStateRecorded), findsOneWidget);
        expect(find.text(_en.stockCountsLine('Coffee beans', 'MAIN', '10 kg', '12.5 kg', '-2.5 kg')), findsOneWidget);
        expect(w.ledger.balance('demo-item-beans', 'demo-place-main').text, '12.5');
      });

      testWidgets('the approval applies exactly the difference', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await _recordCount(tester, '10');
        final id = (await w.reversals.counts('ws-1')).single.countId;
        await tester.tap(find.byKey(ValueKey('stock-count-apply-$id')));
        await _settle(tester);
        expect(find.text(_en.stockCountsStateApplied), findsOneWidget);
        expect(w.ledger.balance('demo-item-beans', 'demo-place-main').text, '10');
        expect(w.ledger.movements.first.reason, 'adjustment');
        expect(find.byKey(ValueKey('stock-count-apply-$id')), findsNothing);
      });

      testWidgets('a count the stock has moved since says to count again and offers no apply', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await _recordCount(tester, '10');
        final id = (await w.reversals.counts('ws-1')).single.countId;
        final beans = w.ledger.itemOf('demo-item-beans')!;
        await w.ledger.post(
          DemoStockPost(item: beans, quantity: ExactQuantity.parse('1'), from: 'demo-place-main', to: 'demo-place-shelf', reason: 'transfer'),
        );
        await tester.tap(find.byKey(const ValueKey('stock-counts-reload')));
        await _settle(tester);
        expect(find.byKey(ValueKey('stock-count-stale-$id')), findsOneWidget);
        expect(find.byKey(ValueKey('stock-count-apply-$id')), findsNothing);
        expect(find.byKey(ValueKey('stock-count-cancel-$id')), findsOneWidget);
      });

      testWidgets('a person who counts but cannot approve sees it waiting, with no apply', (tester) async {
        final w = _World();
        await _open(tester, w, size, held: _count);
        await _recordCount(tester, '10');
        final id = (await w.reversals.counts('ws-1')).single.countId;
        expect(find.text(_en.stockCountsStateRecorded), findsOneWidget);
        expect(find.byKey(ValueKey('stock-count-apply-$id')), findsNothing);
        expect(find.byKey(ValueKey('stock-count-cancel-$id')), findsOneWidget);
      });

      testWidgets('rejecting moves nothing', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await _recordCount(tester, '10');
        final id = (await w.reversals.counts('ws-1')).single.countId;
        await tester.tap(find.byKey(ValueKey('stock-count-reject-$id')));
        await _settle(tester);
        expect(find.text(_en.stockCountsStateRejected), findsOneWidget);
        expect(w.ledger.balance('demo-item-beans', 'demo-place-main').text, '12.5');
      });

      testWidgets('a person who only looks cannot count', (tester) async {
        final w = _World();
        await _open(tester, w, size, held: {WorkspacePermission.viewStock});
        expect(find.byKey(const ValueKey('stock-count-open')), findsNothing);
      });

      testWidgets('a count of nothing counted is said under the field', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await tester.tap(find.byKey(const ValueKey('stock-count-open')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-count-submit')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-count-observed')), findsOneWidget);
        expect(w.reversals.counts('ws-1'), completion(isEmpty));
      });
    });
  }

  test('a count of another content under its identity is refused', () async {
    final w = _World();
    await w.reversals.recordCount('ws-1', _draft('10', 'r-1'));
    await expectLater(
      w.reversals.recordCount('ws-1', _draft('9', 'r-2')),
      throwsA(isA<Object>()),
    );
    expect((await w.reversals.counts('ws-1')).single.state, StockCountState.recorded);
  });
}
