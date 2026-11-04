// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 3 — the Demo use case of the sales figures: in each of the
// four spaces, the analytics page reads what the space sold by kind of
// line and by service from that space's own invoices, in its own currency,
// never mixed; Pézenas reads the margin of the Studio it rents, its
// bookings set against its rent.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/sales_kpi_providers.dart';
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
    test('$name reads its sales in $currency', () async {
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
      final from = _month(DateTime.utc(fixture.seededAt.year));
      final k = await container
          .read(salesKpiRepositoryProvider)
          .quality(workspace.id, fromMonth: from, toMonth: to);
      expect(k.currency, currency);
      expect(k.reasons, isNot(contains('currency_mix')));
      expect(k.netMinor, greaterThan(0));
      expect(k.grossMinor, greaterThanOrEqualTo(k.netMinor!));
      expect(k.kinds, isNotEmpty);
      final rents = container
          .read(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.externalRooms);
      expect(k.rooms == null, !rents);
      if (name == 'Pézenas' && rents) {
        final studio = k.rooms!.rows.singleWhere((r) => r.name == 'Studio');
        expect(studio.uses, greaterThan(0));
        expect(studio.chargesMinor, greaterThan(0));
        expect(studio.costMinor, greaterThan(0));
        expect(studio.marginMinor, studio.chargesMinor! - studio.costMinor!);
      }
    });
  }
}
