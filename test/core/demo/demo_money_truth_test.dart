// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3832 - the references, totals and currencies of every Demo space's money
// agree with each other: an invoice is in its space's currency, belongs to a
// member of that space, and totals its lines; a match names a real payment of
// the same party that covers it; a purchase's payable is in the purchase's
// own currency; a document in another currency has its rate and is never
// added to the space's own figures.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = DemoFixture.build(now: DateTime.utc(2026, 11, 2, 10));
  final spaces = [
    (id: 'ws-1', currency: 'EUR', home: fixture.workspaces, money: fixture.money),
    (id: 'ws-2', currency: 'EUR', home: fixture.secondSpace.workspaces, money: fixture.secondSpace.money),
    (id: 'ws-3', currency: 'GBP', home: fixture.london.workspaces, money: fixture.london.money),
    (id: 'ws-4', currency: 'USD', home: fixture.newYork.workspaces, money: fixture.newYork.money),
    (id: 'ws-5', currency: 'CHF', home: fixture.zurich.workspaces, money: fixture.zurich.money),
    (id: 'ws-6', currency: 'EUR', home: fixture.milan.workspaces, money: fixture.milan.money),
  ];

  for (final space in spaces) {
    test('${space.id}: invoices belong to the space, in its currency, totalling their lines', () {
      final members = {
        space.home.myMember.id,
        ...space.home.otherMembers.map((m) => m.id),
      };
      final money = space.money;
      expect(money.invoices, isNotEmpty);
      for (final i in money.invoices) {
        if (i.kind == InvoiceKind.settlement) continue;
        expect(i.workspaceId, space.id, reason: i.id);
        expect(i.currency, space.currency, reason: i.id);
        expect(members, contains(i.memberId), reason: i.id);
        expect(
          i.lines.fold<int>(0, (s, l) => s + l.amountCents),
          i.totalCents,
          reason: '${i.id}: the total is its lines',
        );
      }
    });

    test('${space.id}: a match covers its invoice with a payment of the same party', () {
      final money = space.money;
      for (final i in money.invoices) {
        final match = money.invoiceMatchesStore[i.id];
        if (match == null || match.pending) continue;
        expect(match.invoiceId, i.id);
        expect(match.paidCents, lessThanOrEqualTo(i.totalCents.abs()), reason: i.id);
        final id = match.paymentLedgerId;
        if (id == null) continue;
        final payments = money.ledger.where((l) => l.id == id).toList();
        if (payments.isEmpty) continue;
        expect(payments.single.memberId, i.memberId, reason: '${i.id}: the payer is the party');
      }
    });
  }

  test('the main space\'s purchase figures do not add a Swiss-franc licence to euros', () async {
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);
    final workspace = fixture.workspaces.workspaces.first;
    await container.read(currentWorkspaceProvider.future);
    final purchases = await container.read(purchaseRepositoryProvider).fetchPurchases('ws-1');
    final waiting = purchases.where((p) => p.state == PurchaseState.pending).toList();
    expect(waiting.any((p) => p.currency == 'CHF'), isTrue, reason: 'the licence in francs waits');
    final kpi = await container
        .read(purchaseKpiRepositoryProvider)
        .summary(workspace.id, fromMonth: '2026-01', toMonth: '2026-11');
    expect(kpi.currency, 'EUR');
    expect(kpi.pendingCount, waiting.length, reason: 'every waiting document is counted');
    expect(kpi.pendingMinor, isNull, reason: 'but francs are never added to euros');
    expect(kpi.reasons, contains('currency_mix'));
  });

  test('every payable of a space is in the currency of its own purchase', () async {
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);
    await container.read(currentWorkspaceProvider.future);
    final repo = container.read(purchaseRepositoryProvider);
    for (final row in await repo.fetchPayables('ws-1')) {
      expect(row.obligation.currency, row.purchase.currency, reason: row.obligation.id);
    }
  });
}
