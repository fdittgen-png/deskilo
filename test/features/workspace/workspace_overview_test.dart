// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2583 C1 — the overview: what needs the person first, then one tile per
// analytics module they may read, grouped Capacity / Sales / Purchases /
// Cash, each the module's own figure; a figure the server cannot give says
// so, never 0; the memberships only for who manages the members.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/attention.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/cost_allocation_rules.dart';
import 'package:deskilo/features/workspace/domain/kpi_overview.dart';
import 'package:deskilo/features/workspace/domain/kpi_purchases.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/screens/workspace_overview_screen.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:deskilo/features/workspace/providers/cost_allocation_providers.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/overview_kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

class _Purchases implements PurchaseKpiRepository {
  @override
  Future<PurchaseSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => purchaseSummaryFromJson({
    'from': fromMonth,
    'to': toMonth,
    'currency': 'EUR',
    'ap_outstanding_minor': '400',
    'member_due_minor': '70',
    'pending_count': 2,
    'pending_minor': '500',
    'outflows_minor': '600',
    'outflows': 1,
    'quality': const <String>[],
    'reasons': const <String>[],
    'computed_at': '2026-05-02T10:00:00Z',
  });
}

/// Today: five active memberships; 12.00 overdue over two invoices, one
/// without a proven due date apart.
class _Overview implements OverviewKpiRepository {
  @override
  Future<OverviewFigure> figure(
    String workspaceId,
    String kpiId, {
    required String fromMonth,
    required String toMonth,
  }) async => overviewFigureFromJson({
    'value': kpiId == 'sales.overdue_receivables' ? '1200' : 5,
    'count': kpiId == 'sales.overdue_receivables' ? 2 : 5,
    'currency': kpiId == 'sales.overdue_receivables' ? 'EUR' : '',
    'unknown_due_count': 1,
    'held_count': 0,
    'quality': const <String>[],
    'reasons': const <String>[],
    'computed_at': '2026-05-02T10:00:00Z',
  });
}

List<Override> _overrides({
  required Set<WorkspaceFeature> features,
  required Set<WorkspacePermission> rights,
  List<Attention> attention = const [],
  SetupStatus? setup,
}) => [
  ...standardTestOverrides(
    workspace: FakeWorkspaceRepository.withWorkspace(),
    localSetup: setup == null ? null : FakeLocalSetupRepository(status: setup),
  ),
  enabledFeaturesSyncProvider.overrideWithValue(features),
  myPermissionsProvider.overrideWithValue(rights),
  attentionProvider.overrideWith((ref) async => attention),
  purchaseKpiRepositoryProvider.overrideWithValue(_Purchases()),
  overviewKpiRepositoryProvider.overrideWithValue(_Overview()),
  costKpiRepositoryProvider.overrideWithValue(
    const UnavailableCostKpiRepository(),
  ),
  costAllocationRepositoryProvider.overrideWithValue(
    const UnavailableCostAllocationRepository(),
  ),
];

void main() {
  test('every module has a group, the sales and cash ones where they '
      'belong', () {
    expect(
      overviewGroupOf(
        biModules.firstWhere((m) => m.id == 'sales.overdue_receivables'),
      ),
      OverviewGroup.sales,
    );
    expect(
      overviewGroupOf(
        biModules.firstWhere(
          (m) => m.id == 'people.active_memberships_current',
        ),
      ),
      OverviewGroup.people,
    );
    BiModule byId(String id) => biModules.firstWhere((m) => m.id == id);
    expect(overviewGroupOf(byId('finance.invoiced')), OverviewGroup.sales);
    expect(overviewGroupOf(byId('cash.recorded_outflows')), OverviewGroup.cash);
    expect(
      overviewGroupOf(byId('purchases.ap_outstanding')),
      OverviewGroup.purchases,
    );
    expect(
      overviewGroupOf(byId('capacity.seat_utilisation')),
      OverviewGroup.capacity,
    );
  });

  testWidgets('nothing to do and no figure to read: the page says so and '
      'shows no indicator', (tester) async {
    await pumpApp(
      tester,
      const WorkspaceOverviewScreen(),
      overrides: _overrides(features: const {}, rights: const {}),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('overview-attention-empty')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('overview-indicators')), findsNothing);
    expect(find.byKey(const ValueKey('overview-group-people')), findsNothing);
  });

  testWidgets('a finance reader sees the purchase figures grouped, the '
      'known ones as numbers and the unknown ones as unavailable', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const WorkspaceOverviewScreen(),
      size: const Size(1200, 3000),
      overrides: _overrides(
        features: {
          WorkspaceFeature.purchaseAnalytics,
          WorkspaceFeature.workspaceOverview,
        },
        rights: {
          WorkspacePermission.viewAnalytics,
          WorkspacePermission.viewFinances,
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-group-purchases')), findsOne);
    expect(find.byKey(const ValueKey('overview-group-cash')), findsOne);
    expect(find.byKey(const ValueKey('overview-group-capacity')), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('overview-value-purchases.pending_reviews'),
            ),
          )
          .data,
      '2',
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('overview-tile-purchases.operating_costs'),
        ),
        matching: find.text('Not available'),
      ),
      findsOneWidget,
      reason: 'a cost the server cannot give is unavailable, never 0',
    );
    // #2583 — the overview's own figures, from the server (0536).
    expect(find.byKey(const ValueKey('overview-group-people')), findsOne);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey(
                'overview-value-people.active_memberships_current',
              ),
            ),
          )
          .data,
      '5',
    );
    expect(find.byKey(const ValueKey('overview-group-sales')), findsOne);
    expect(
      find.byKey(const ValueKey('overview-tile-sales.overdue_receivables')),
      findsOne,
    );
  });

  test('an overdue amount that cannot travel exactly is unknown, never 0', () {
    final f = overviewFigureFromJson({
      'value': '12.5',
      'count': 1,
      'currency': 'EUR',
      'quality': const <String>[],
      'reasons': const <String>[],
      'computed_at': '2026-05-02T10:00:00Z',
    });
    expect(f.value, isNull);
    expect(f.reasons, contains('amount_not_exact'));
  });

  group('#2869 — an unfinished setup', () {
    final open = SetupStatus.fromJson({
      'steps': [
        {
          'step': 'places',
          'milestone': 'bookable',
          'required': true,
          'state': 'needs_configuration',
          'route': '/editor',
        },
      ],
      'milestones': [
        {
          'milestone': 'bookable',
          'applies': true,
          'required': 1,
          'ready': 0,
          'reached': false,
        },
      ],
    });

    testWidgets('a configurer sees where to resume first', (tester) async {
      await pumpApp(
        tester,
        const WorkspaceOverviewScreen(),
        overrides: _overrides(
          features: const {WorkspaceFeature.setupGuide},
          rights: const {WorkspacePermission.manageConfiguration},
          setup: open,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setup-resume-banner')), findsOneWidget);
    });

    testWidgets('someone who cannot configure does not', (tester) async {
      await pumpApp(
        tester,
        const WorkspaceOverviewScreen(),
        overrides: _overrides(
          features: const {WorkspaceFeature.setupGuide},
          rights: const {},
          setup: open,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setup-resume-banner')), findsNothing);
    });
  });
}
