// SPDX-License-Identifier: AGPL-3.0-or-later
// Every demo space owns its purchase and accounting records; country inputs
// agree with the invoices, orders and figures a visitor can actually open.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_twin_seed.dart';
import 'package:deskilo/features/money/providers/accounting_connection_providers.dart';
import 'package:deskilo/features/money/providers/book_period_providers.dart';
import 'package:deskilo/features/money/providers/book_profile_providers.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DemoFixture fixture;
  late ProviderContainer container;
  setUp(() {
    fixture = DemoFixture.build(now: DateTime.utc(2026, 11, 13, 10));
    container = ProviderContainer(overrides: demoOverrides(fixture))
      ..listen(currentWorkspaceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  Future<void> enter(String id) async {
    await container.read(currentWorkspaceProvider.future);
    container.read(activeWorkspaceIdProvider.notifier).activate(id);
    expect((await container.read(currentWorkspaceProvider.future))?.id, id);
  }

  test('the development twin starts with its own empty purchase orders', () async {
    await enter('ws-1');
    final home = container.read(purchaseOrderRepositoryProvider);
    final before = await home.fetchOrders('ws-1');
    expect(before, isNotEmpty);
    await enter(demoTwinSpaceId);
    final twin = container.read(purchaseOrderRepositoryProvider);
    expect(twin, isNot(same(home)));
    expect(await twin.fetchOrders(demoTwinSpaceId), isEmpty);
    expect(await home.fetchOrders('ws-1'), before);
  });

  test('Leipzig keeps its own book periods and accounting connections', () async {
    await enter('ws-1');
    final homePeriods = container.read(bookPeriodRepositoryProvider);
    final homeConnections = container.read(accountingConnectionRepositoryProvider);
    await enter('ws-2');
    final periods = container.read(bookPeriodRepositoryProvider);
    final connections = container.read(accountingConnectionRepositoryProvider);
    expect(periods, isNot(same(homePeriods)));
    expect(connections, isNot(same(homeConnections)));
    expect((await periods.fetch('ws-2')).periods, isEmpty);
    expect(await connections.fetchConnections('ws-2'), isEmpty);
  });

  test('purchase order taxes follow each country fixture', () async {
    for (final (id, currency, percent) in [
      ('ws-3', 'GBP', 20.0),
      ('ws-4', 'USD', 0.0),
      ('ws-5', 'CHF', 8.1),
      ('ws-6', 'EUR', 22.0),
    ]) {
      await enter(id);
      final workspace = (await container.read(currentWorkspaceProvider.future))!;
      expect(workspace.currencyCode, currency);
      final orders = await container.read(purchaseOrderRepositoryProvider).fetchOrders(id);
      expect(orders, isNotEmpty);
      for (final order in orders) {
        expect(order.currency, currency);
        expect(order.lines.map((line) => line.vatRatePercent).toSet(), {percent});
      }
    }
  });
  test('approved taxed purchases produce postings with qualified recovery', () async {
    for (final (id, site) in [('ws-3', 'uk-site-camden'),
      ('ws-5', 'ch-site-limmat'), ('ws-6', 'it-site-navigli')]) {
      await enter(id);
      final postings = await container.read(bookProfileRepositoryProvider)
        .fetchPostings(id, site, DateTime.utc(2025), fixture.seededAt);
      expect(postings.postings, isNotEmpty);
      expect(postings.blockers.map((b) => b.block),
        isNot(contains(PostingBlock.unclassifiedTax)));
    }
  });

}
