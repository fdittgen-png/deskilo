// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 (row 11) -- what the Demo holds of a grocery shop's flow (order, receive, break down, part on the shelf, where
// is it, shelf life, stock value, sale, waste, ranking), read through the ports the screens read, in the two businesses
// that keep goods: the reference business a visitor lands in as the owner (Atelier du Marché), and the shop its member
// owns (Épicerie du Marché). Each step the Demo holds is asserted on its seeded records and on one command a visitor
// can run; each step it does not hold is a skipped test that names what is missing, so the gap is a line of the run and
// not a sentence in a report. The invariant: the parts named here stay present, and a filled gap loses its skip.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/core/demo/seed/demo_shop_seed.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/providers/counter_book_providers.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/till_providers.dart';
import 'package:deskilo/features/stock/domain/handling_units.dart';
import 'package:deskilo/features/stock/domain/stock_expiry.dart';
import 'package:deskilo/features/stock/domain/stock_operations.dart';
import 'package:deskilo/features/stock/domain/stock_receiving.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;

/// The switches the ten steps need: the order, the stock with its lots, receiving, taking out, the units, the expiry
/// report and the till.
const _flow = [
  WorkspaceFeature.purchaseOrders,
  WorkspaceFeature.stockManagement,
  WorkspaceFeature.stockLots,
  WorkspaceFeature.stockReceiving,
  WorkspaceFeature.stockTakeOut,
  WorkspaceFeature.stockHandlingUnits,
  WorkspaceFeature.stockExpiryReport,
  WorkspaceFeature.counterReceipts,
];

const _mugs = 'demo-item-mugs';
const _beans = 'demo-item-beans';
const _milk = 'demo-item-milk';

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the Demo as [persona] on My spaces and answers the app's container and the spaces listed.
Future<(ProviderContainer, Set<String>)> _open(WidgetTester tester, DemoPersona persona) async {
  await pumpDemo(tester, persona: persona, openHub: false, size: const Size(390, 2400));
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/me');
  await _frames(tester);
  final listed = {
    for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('me-space-ws')).evaluate())
      (e.widget.key! as ValueKey<String>).value.substring('me-space-'.length),
  };
  return (ProviderScope.containerOf(tester.element(find.byType(DeskiloApp))), listed);
}

ExactQuantity _q(String text) => ExactQuantity.parse(text);

void main() {
  testWidgets('the reference business holds seven of the ten steps, each on goods of its own', (tester) async {
    const ws = demoFirstSpaceId;
    final (c, listed) = await _open(tester, DemoPersona.owner);
    expect(listed, contains(ws));
    expect(listed, isNot(contains(demoShopSpaceId)), reason: 'the owner the visitor lands as is not a member of the shop');
    final queries = c.read(stockQueriesProvider);
    final places = {for (final p in await c.read(stockConfigCommandsProvider).places(ws)) p.code: p.id};
    final main = places['MAIN']!;
    final shelf = places['SHELF-A']!;
    Future<ExactQuantity> held(String item, String place) async => [
      for (final r in (await queries.onHandPage(ws, itemId: item, locationId: place)).rows) r.quantity,
    ].fold<ExactQuantity>(ExactQuantity.zero, (s, q) => s + q);

    // 1. order: an order awaited and one partly received, for goods the business keeps, with a unit and a price
    final orders = await c.read(purchaseOrderRepositoryProvider).fetchOrders(ws);
    final awaited = orders.firstWhere((o) => o.state == PurchaseOrderState.sent);
    final partly = orders.firstWhere((o) => o.state == PurchaseOrderState.partlyReceived);
    expect(awaited.lines.first.serviceId, _mugs);
    expect((awaited.lines.first.unit, awaited.lines.first.unitPriceCents > 0), ('box', true));
    expect(partly.lines.first.serviceId, _beans);

    // 2. receive: what arrived of the partly received order is put away, at a cost, and the stock grows by it
    final before = await held(_beans, main);
    final put = await c.read(stockReceivingCommandsProvider).putAway(ws, 'demo-receipt-3', [
      PutAwayAllocation(lineNo: 1, quantity: '5', locationId: main, cost: const PutAwayCost.known(totalMinor: 8000)),
    ], 'grocery-story-put-away');
    expect(put.allocations.single.itemId, _beans);
    expect(await held(_beans, main), before + _q('5'));
    expect((await c.read(stockReceivingCommandsProvider).allocationsOfOrder(ws, partly.id)).map((a) => a.movementId), contains(put.allocations.single.movementId),
        reason: 'the order leads to what was put away of it');

    // 3. break down: a pallet and a carton stand in the main store; the pallet is unpacked where it stands
    final units = c.read(stockHandlingUnitsProvider);
    final pallet = (await units.page(ws)).rows.firstWhere((u) => u.kind == HandlingUnitKind.pallet);
    expect((await units.unit(ws, pallet.id))!.lines.single.itemId, _mugs);
    final mugsBefore = await held(_mugs, main);
    expect((await units.unpack(ws, 'grocery-story-unpack', unitId: pallet.id, revision: pallet.revision)).state, HandlingUnitState.unpacked);
    expect(await held(_mugs, main), mugsBefore, reason: 'unpacking changes no balance');

    // 4. part on the shelf: the mugs are split between the main store and a shelf, and a move refills the shelf
    final onShelf = await held(_mugs, shelf);
    expect(ExactQuantity.zero < onShelf && ExactQuantity.zero < mugsBefore, isTrue);
    await c.read(stockOperationsProvider).transfer(ws, [StockLineDraft(itemId: _mugs, quantity: '2', fromLocationId: main, toLocationId: shelf)], 'grocery-story-refill');
    expect(await held(_mugs, shelf), onShelf + _q('2'));

    // 9. waste: a mug is written off from the shelf
    await c.read(stockOperationsProvider).takeOut(ws, StockTakeOutReason.loss, [StockLineDraft(itemId: _mugs, quantity: '1', fromLocationId: shelf)], 'grocery-story-loss', loss: const StockLoss(cause: StockLossCause.damaged));
    expect((await queries.movementsPage(ws, limit: 5)).rows.first.reason, 'loss');

    // 5. where is it: every place of the mugs, what was sold and what was written off, and the places add up
    final where = await c.read(stockWhereIsProvider).whereIs(ws, _mugs);
    expect(where.balances, isTrue);
    expect({for (final p in where.real) p.locationCode}, containsAll(['MAIN', 'SHELF-A']));
    expect({for (final d in where.documents) d.reason}, containsAll(['sale', 'loss']));

    // 6. shelf life: something expired and something expiring, each at its place; the till reads the milk's lots, the expired one marked
    final expiry = await c.read(stockExpiryProvider).report(ws, const ExpiryQuery());
    expect(expiry.rows.any((r) => r.days < 0) && expiry.rows.any((r) => r.days >= 0), isTrue);
    expect(expiry.rows.every((r) => r.locationCode.isNotEmpty), isTrue);
    final lots = await c.read(tillLotsPortProvider)!.lots(ws, _milk);
    expect((lots.first.expired, lots.last.expired), (true, false));

    // 7. stock value: a known total, and the goods with no known cost left outside it
    final value = await c.read(stockTraceReaderProvider).valuation(ws);
    expect(value.knownTotalMinor, greaterThan(0));
    expect(value.complete, isFalse);
    expect([for (final u in value.uncosted) u.itemId], [_mugs]);

    // 8. sale: the counter's book holds issued receipts with goods lines
    final book = await c.read(counterBookPortProvider).book(ws);
    expect(book.issued.expand((r) => r.lines).where((l) => l.goods), isNotEmpty);

    // every switch of the flow is on in this business
    expect(resolveEnabledFeatures(c.read(currentWorkspaceProvider).value!.featureFlags), containsAll(_flow));
  });

  testWidgets('the shop is entered by its owner and keeps goods, with no order of its own', (tester) async {
    final (c, listed) = await _open(tester, DemoPersona.member);
    expect(listed, containsAll([demoFirstSpaceId, demoShopSpaceId]), reason: 'the member owns the shop and belongs to the reference business');
    expect(DemoSpaceKey.listedAtStart, isNot(contains(DemoSpaceKey.shop)));
    final space = find.byKey(const ValueKey('me-space-$demoShopSpaceId'));
    await tester.scrollUntilVisible(space, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(space);
    await tester.pump();
    await tester.tap(space);
    await _frames(tester);
    const ws = demoShopSpaceId;
    final on = resolveEnabledFeatures(demoShopSpace().featureFlags);
    expect(on, containsAll([WorkspaceFeature.purchaseOrders, WorkspaceFeature.stockManagement, WorkspaceFeature.stockLots, WorkspaceFeature.stockReceiving, WorkspaceFeature.stockTakeOut]));
    expect((await c.read(stockQueriesProvider).onHandPage(ws)).rows, isNotEmpty, reason: 'its ledger mirrors the reference business');
    expect((await c.read(stockTraceReaderProvider).valuation(ws)).knownTotalMinor, greaterThan(0));
    expect(await c.read(purchaseOrderRepositoryProvider).fetchOrders(ws), isEmpty, reason: 'while this holds, step 1 is not in the shop');
    expect((await c.read(counterBookPortProvider).book(ws)).receipts, isEmpty, reason: 'while this holds, step 8 is not in the shop');
  });

  test('the switches of the shop are those of its kind: stock and orders, the till, the expiry report and the handling units', () {
    expect(_flow.toSet().difference(resolveEnabledFeatures(demoShopSpace().featureFlags)), isEmpty,
        reason: 'the shop kind proposes what a shop needs (0982)');
  });

  // ── what the Demo does not hold ──────────────────────────────────────────────────────────────────────────────────────
  test('the grocery has the till, the expiry report and the handling units switched on', () {
    expect(resolveEnabledFeatures(demoShopSpace().featureFlags), containsAll(_flow));
  });

  test('GAP step 1-2: a product with a best-before date is on an open order, so its lot and date are captured at the put-away', () {},
      skip: 'the ordered Demo items (mugs, beans) are tracked by nothing: the put-away sheet shows no lot and no date field');

  test('GAP step 2/5/6/7: a lot put away in the Demo keeps its date and its cost, and shows in the expiry report, where-is and the value', () {},
      skip: 'DemoStockReceivingCommands books the lot code only; DemoStockExpiry is a fixed list; the value reads the catalogue cost');

  test('GAP step 3: the Demo pallet holds boxes, and its lines carry a lot with its date', () {},
      skip: 'PAL-001 and CT-001 hold loose goods of no lot; DemoStockHandlingUnits.lotTrace answers nothing');

  test('GAP step 6: the lots of the expiry report are the ledger\'s', () {},
      skip: 'the report lists 8 l of oat milk in two lots at MAIN; the ledger holds 24 l of no lot');

  test('GAP step 8: a Demo till sale takes the goods out of the Demo ledger, and one seeded sale is marked down', () {},
      skip: 'DemoTill prices from the catalogue and moves no stock; its two seeded receipts are at the item\'s price');

  test('GAP step 9: a write-off is seeded', () {}, skip: 'no movement of the Demo\'s story goes to the loss place; the command works (asserted above)');

  test('GAP step 10: the products are ranked', () {}, skip: 'the app has no ranking of products sold at the till: the Demo gap follows the app gap');
}
