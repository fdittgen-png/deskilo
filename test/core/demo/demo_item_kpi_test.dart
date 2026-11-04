// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 4 — the Demo use case of the item figures: London and New York
// restock their snacks and bottled water from named suppliers and sell
// them on their members' invoices, so the analytics page reads each item's
// unit price by supplier, the margin each product leaves and the margin
// each supplier's price leaves, in the space's own currency.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/workspace/providers/item_kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _month(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

void main() {
  final fixture = DemoFixture.build(now: DateTime.utc(2026, 11, 2, 10));
  for (final (name, id, currency, workspaces) in [
    ('London', 'ws-3', 'GBP', fixture.london.workspaces),
    ('New York', 'ws-4', 'USD', fixture.newYork.workspaces),
  ]) {
    test('$name reads its items in $currency', () async {
      final workspace = workspaces.workspaces.firstWhere((w) => w.id == id);
      final container = ProviderContainer(
        overrides: [
          ...demoOverrides(fixture),
          currentWorkspaceProvider.overrideWith((ref) async => workspace),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentWorkspaceProvider.future);
      final to = _month(
        DateTime.utc(fixture.seededAt.year, fixture.seededAt.month - 1),
      );
      final from = _month(
        DateTime.utc(fixture.seededAt.year, fixture.seededAt.month - 6),
      );
      final k = await container
          .read(itemKpiRepositoryProvider)
          .quality(workspace.id, fromMonth: from, toMonth: to);
      expect(k.currency, currency);
      expect(k.reasons, isNot(contains('currency_mix')));
      expect(k.prices, isNotEmpty);
      expect(k.prices.every((p) => (p.unitPriceMinor ?? 0) > 0), isTrue);
      final snacks = k.products.firstWhere(
        (p) => p.item == 'Sweets and snacks',
      );
      expect(snacks.unitCostMinor, isNotNull);
      expect(snacks.marginMinor, snacks.revenueMinor! - snacks.costMinor!);
      expect(k.vendors, isNotEmpty);
      expect(k.vendorPremiumMinor, isNotNull);
    });
  }
}
