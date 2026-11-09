// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 2 — the Demo use case of the vendor figures: in each of the
// four spaces, the analytics page reads what the space bought and from
// whom, how punctually it paid its suppliers and how late their bills
// arrived, from that space's own purchases, in its own currency, never
// mixed. London and New York carry months of bills with their due dates,
// late payments and arrival days.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/workspace/domain/kpi_vendors.dart';
import 'package:deskilo/features/workspace/providers/vendor_kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _month(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

void main() {
  final fixture = DemoFixture.build(now: DateTime.utc(2026, 11, 2, 10));
  for (final (name, id, currency, workspaces, city) in [
    ('Pézenas', 'ws-1', 'EUR', fixture.workspaces, false),
    ('Leipzig', 'ws-2', 'EUR', fixture.secondSpace.workspaces, false),
    ('London', 'ws-3', 'GBP', fixture.london.workspaces, true),
    ('New York', 'ws-4', 'USD', fixture.newYork.workspaces, true),
  ]) {
    test('$name reads its suppliers in $currency', () async {
      final workspace = workspaces.workspaces.firstWhere((w) => w.id == id);
      final container = ProviderContainer(
        overrides: [
          ...demoOverrides(fixture),
          currentWorkspaceProvider.overrideWith((ref) async => workspace),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentWorkspaceProvider.future);
      final to = _month(fixture.seededAt);
      final from = _month(
        DateTime.utc(fixture.seededAt.year - 1, fixture.seededAt.month + 1),
      );
      final k = await container
          .read(vendorKpiRepositoryProvider)
          .quality(workspace.id, fromMonth: from, toMonth: to);
      expect(k.currency, currency);
      expect(k.reasons, isNot(contains('currency_mix')));
      expect(k.costMinor, greaterThan(0));
      expect(k.vendors, isNotEmpty);
      expect(k.vendors.map((v) => v.rank), [
        for (var r = 1; r <= k.vendors.length; r++) r,
      ]);
      expect(k.vendors.every((v) => v.name.isNotEmpty), isTrue);
      expect(
        k.cohorts.values.fold<int>(0, (s, c) => s + c.count),
        greaterThan(0),
        reason: 'supplier payables fell due in the last twelve months',
      );
      expect(k.completedCount, greaterThan(0));
      if (city) {
        expect(
          k.cohorts[PayableCohort.late]!.count,
          greaterThan(0),
          reason: 'one bill in four is paid after its due date',
        );
        expect(k.lagDocuments, greaterThan(0));
        expect(k.lagDays, greaterThan(0));
        expect(k.medianDays, lessThan(0), reason: 'most bills are paid early');
      }
      // #3294 step 5 -- the orders the space sent, by whether their goods
      // arrived by the expected date: each order in exactly one cohort,
      // from that space's own orders and receipts.
      expect(
        k.deliveryCohorts.values.fold<int>(0, (s, n) => s + n),
        k.deliveryOrders,
        reason: 'each order is in exactly one cohort',
      );
      expect(k.deliveryOrders, greaterThan(0), reason: '$name sent orders');
      expect(
        k.deliveries.fold<int>(0, (s, d) => s + d.orders),
        k.deliveryOrders,
      );
    });
  }
}
