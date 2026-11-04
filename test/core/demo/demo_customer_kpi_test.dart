// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 — the Demo use case of the customer figures: in each of the four
// spaces, the analytics page reads how its customers pay, the dunning, the
// credits and write-offs and the concentration from that space's own
// invoices, in its own currency, never mixed; the names follow the
// persona's right to personal data, as the server decides them.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/customer_kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _month(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

void main() {
  final fixture = DemoFixture.build(now: DateTime.utc(2026, 11, 2, 10));
  for (final (name, id, currency, workspaces) in [
    ('Pézenas', 'ws-1', 'EUR', fixture.workspaces),
    ('Leipzig', 'ws-2', 'EUR', fixture.secondSpace.workspaces),
    ('London', 'ws-3', 'GBP', fixture.london.workspaces),
    ('New York', 'ws-4', 'USD', fixture.newYork.workspaces),
  ]) {
    test('$name reads its customers in $currency', () async {
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
          .read(customerKpiRepositoryProvider)
          .quality(workspace.id, fromMonth: from, toMonth: to);
      expect(k.currency, currency);
      expect(k.reasons, isNot(contains('currency_mix')));
      expect(
        k.cohorts.values.fold<int>(0, (s, c) => s + c.count),
        greaterThan(0),
        reason: 'invoices fell due in the last twelve months',
      );
      expect(k.netMinor, greaterThan(0));
      expect(k.customers, isNotEmpty);
      expect(
        k.customers.map((c) => c.rank),
        [for (var r = 1; r <= k.customers.length; r++) r],
      );
      expect(
        k.namesVisible,
        container
            .read(myPermissionsProvider)
            .contains(WorkspacePermission.viewPersonalData),
      );
    });
  }
}
