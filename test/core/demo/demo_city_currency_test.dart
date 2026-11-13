// SPDX-License-Identifier: AGPL-3.0-or-later
// New York is in dollars and London in pounds, in every figure the Demo shows
// for them: the workspace row, the invoices, the purchase documents and the
// purchase and cost figures. Never the euro of the older spaces.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _month(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

void main() {
  final fixture = DemoFixture.build(now: DateTime.utc(2026, 11, 2, 10));
  for (final (name, currency, space) in [
    ('London', 'GBP', fixture.london.workspaces),
    ('New York', 'USD', fixture.newYork.workspaces),
  ]) {
    test('$name is in $currency everywhere', () async {
      final workspace = space.workspaces.firstWhere((w) => w.id == (name == 'London' ? 'ws-3' : 'ws-4'));
      expect(workspace.currencyCode, currency);
      final features = resolveEnabledFeatures(workspace.featureFlags);
      expect(features, isNot(contains(WorkspaceFeature.recordingPrivacy)));
      expect(features, isNot(contains(WorkspaceFeature.mcpAccess)));
      expect(features, isNot(contains(WorkspaceFeature.webMcp)));
      expect(features.contains(WorkspaceFeature.mtdSubmission), name == 'London');
      final money = name == 'London' ? fixture.london.money : fixture.newYork.money;
      expect(money.invoices, isNotEmpty);
      expect({for (final i in money.invoices) i.currency}, {currency});

      final status = await money.fetchWorkspaceStatus(workspace.id, '${fixture.seededAt.year - 3}-01', _month(fixture.seededAt));
      expect(status.currency, currency, reason: 'the workspace status reads in the space currency');

      final container = ProviderContainer(
        overrides: [
          ...demoOverrides(fixture),
          currentWorkspaceProvider.overrideWith((ref) async => workspace),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentWorkspaceProvider.future);
      final from = _month(DateTime.utc(fixture.seededAt.year - 3, fixture.seededAt.month));
      final to = _month(fixture.seededAt);
      final purchase = await container.read(purchaseKpiRepositoryProvider).summary(workspace.id, fromMonth: from, toMonth: to);
      expect(purchase.currency, currency);
      final cost = await container.read(costKpiRepositoryProvider).summary(workspace.id, fromMonth: from, toMonth: to);
      expect(cost.currency, currency);
      expect(cost.netSalesMinor, greaterThan(0), reason: 'the invoices are net sales');
      expect(cost.operatingCostsMinor, greaterThan(0), reason: 'the approved bills are operating costs');
      expect(cost.contributionMinor, cost.netSalesMinor! - cost.operatingCostsMinor!);
    });
  }

  // #3867 - every space of the one list reads in its own currency: its
  // workspace row, its invoices, its purchase and cost figures.
  for (final key in DemoSpaceKey.values) {
    test('${key.label} reads in ${key.currency}', () async {
      final workspace = fixture.spaceWorkspaces.at(key).workspaces.firstWhere((w) => w.id == key.id);
      expect(workspace.currencyCode, key.currency);
      expect({for (final i in fixture.spaceMoney.at(key).invoices) i.currency}.difference({key.currency}), isEmpty);
      final container = ProviderContainer(
        overrides: [
          ...demoOverrides(fixture),
          currentWorkspaceProvider.overrideWith((ref) async => workspace),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentWorkspaceProvider.future);
      final from = _month(DateTime.utc(fixture.seededAt.year - 3, fixture.seededAt.month));
      final to = _month(fixture.seededAt);
      final purchase = await container.read(purchaseKpiRepositoryProvider).summary(key.id, fromMonth: from, toMonth: to);
      expect(purchase.currency, key.currency);
      final cost = await container.read(costKpiRepositoryProvider).summary(key.id, fromMonth: from, toMonth: to);
      expect(cost.currency, key.currency);
    });
  }
}
