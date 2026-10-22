// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C2 — a shared cost spread over resources by largest remainder: the
// issue's own figures, never an even split invented for a missing weight.
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/cost_allocation.dart';
import 'package:deskilo/features/workspace/domain/cost_allocation_rules.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_module_section.dart';
import 'package:deskilo/features/workspace/presentation/widgets/cost_allocation_editor.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:deskilo/features/workspace/providers/cost_allocation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

AllocationWeight _w(String id, int weight, {String kind = 'office'}) =>
    AllocationWeight(resourceKind: kind, resourceId: id, weight: weight);

AllocationShare _s(String id, int minor, {String kind = 'office'}) =>
    AllocationShare(resourceKind: kind, resourceId: id, minor: minor);

void main() {
  test('10001 over 1:1:1 is 3334/3334/3333, the extra units in resource '
      'order, and the shares add up', () {
    final shares = allocateByLargestRemainder(10001, [
      _w('c', 1),
      _w('a', 1),
      _w('b', 1),
    ])!;
    expect(shares, [_s('a', 3334), _s('b', 3334), _s('c', 3333)]);
    expect(shares.fold<int>(0, (sum, s) => sum + s.minor), 10001);
  });

  test('the largest remainder wins before the resource order', () {
    // 100 over 1:2: exact parts 33.33 and 66.67.
    expect(allocateByLargestRemainder(100, [_w('a', 1), _w('b', 2)]), [
      _s('a', 33),
      _s('b', 67),
    ]);
  });

  test('no weight, or weights of 0, allocate nothing: the cost stays '
      'unallocated', () {
    expect(allocateByLargestRemainder(10001, const []), isNull);
    expect(allocateByLargestRemainder(10001, [_w('a', 0), _w('b', 0)]), isNull);
  });

  test('a negative weight or the same resource twice is refused', () {
    expect(allocateByLargestRemainder(100, [_w('a', -1), _w('b', 2)]), isNull);
    expect(allocateByLargestRemainder(100, [_w('a', 1), _w('a', 1)]), isNull);
  });

  test('a zero weight receives nothing, even with units left over', () {
    expect(
      allocateByLargestRemainder(10, [_w('a', 1), _w('b', 0), _w('c', 2)]),
      [_s('a', 3), _s('b', 0), _s('c', 7)],
    );
  });

  test('a credit is spread with its sign', () {
    expect(allocateByLargestRemainder(-10001, [_w('a', 1), _w('b', 1)]), [
      _s('a', -5001),
      _s('b', -5000),
    ]);
  });

  test('resources sort by kind, then id', () {
    final shares = allocateByLargestRemainder(5, [
      _w('x', 1),
      _w('y', 1, kind: 'level'),
    ])!;
    expect(shares.map((s) => s.resourceKind), ['level', 'office']);
    expect(shares.map((s) => s.minor), [3, 2]);
  });

  test('the server\'s allocation reads exactly; direct, shared and '
      'unallocated add up to the operating costs', () {
    final k = costAllocationFromJson(_march());
    expect(k.resources.map((r) => r.allocatedMinor), [3334, 3334, 3333]);
    expect(
      k.directMinor! + k.sharedMinor! + k.unallocatedMinor!,
      k.operatingCostsMinor,
    );
    expect(k.allocatedMinor, 10001);
    expect(k.rulesUsed, [('Floor area', 1)]);
    expect(k.resources.first.revisions, [('rule-1', 1)]);
    final inexact = costAllocationFromJson(_march(shared: '10001.5'));
    expect(inexact.sharedMinor, isNull);
    expect(inexact.quality, contains(KpiQuality.unavailable));
  });

  test('the card: one row per resource, behind the flag and the finance '
      'right', () async {
    expect(
      visibleBiModules(
        {WorkspaceFeature.purchaseAnalytics},
        {WorkspacePermission.viewAnalytics, WorkspacePermission.viewFinances},
      ).map((m) => m.id),
      contains('finance.cost_allocation'),
    );
    expect(biModuleViews.containsKey('finance.cost_allocation'), isTrue);
    final container = ProviderContainer(
      overrides: [
        costAllocationRepositoryProvider.overrideWithValue(_Rules()),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 5, 2))),
      ],
    );
    addTearDown(container.dispose);
    const context = BiQueryContext(
      period: BiPeriodRef.fixed(BiPeriod(BiGrain.month, 2026, 3)),
    );
    final provider = biModuleResultProvider(
      'ws-1',
      'finance.cost_allocation',
      context,
    );
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    final result = await container.read(provider.future);
    expect(result.total.current.value(KpiAggregation.sum), 10001);
    expect(result.groups.map((g) => g.label), [
      'Office 1',
      'Office 2',
      'Office 3',
    ]);
    expect(result.groups.map((g) => g.current.numerator), [3334, 3334, 3333]);
  });

  testWidgets('a new rule: category, basis and weights become one revision; '
      'nothing is saved without a weight', (tester) async {
    final rules = _Rules();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(
            workspace: FakeWorkspaceRepository.withWorkspace(),
          ),
          costAllocationRepositoryProvider.overrideWithValue(rules),
          levelsProvider.overrideWith(
            (ref) async => const [
              Level(
                id: 'lv-1',
                workspaceId: 'ws-1',
                name: 'Ground',
                sortOrder: 0,
              ),
            ],
          ),
          floorPlanProvider('lv-1').overrideWith(
            (ref) async => const FloorPlan(
              levelId: 'lv-1',
              offices: [
                Office(
                  id: 'of-1',
                  workspaceId: 'ws-1',
                  levelId: 'lv-1',
                  name: 'Office 1',
                  color: 0,
                  bookableAsWhole: false,
                  rect: GridRect(x: 0, y: 0, w: 1, h: 1),
                ),
              ],
              desks: [],
              seats: [],
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CostAllocationRulesDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('allocation-rules-empty')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('allocation-new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('allocation-category')),
      'Cleaning',
    );
    await tester.enterText(
      find.byKey(const ValueKey('allocation-basis')),
      'Floor area',
    );
    await tester.tap(find.byKey(const ValueKey('allocation-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('allocation-error')), findsOneWidget);
    expect(rules.saved, isEmpty, reason: 'no weight, no rule');

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('allocation-weight-office-of-1')),
        matching: find.byType(TextField),
      ),
      '3',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('allocation-preview')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('allocation-save')));
    await tester.pumpAndSettle();
    expect(rules.saved, hasLength(1));
    final draft = rules.saved.single;
    expect(draft.category, 'Cleaning');
    expect(draft.basis, 'Floor area');
    expect(draft.toJson()['weights'], [
      {'resource_kind': 'office', 'resource_id': 'of-1', 'weight': 3},
    ]);
  });
}

Map<String, Object?> _march({String shared = '10001'}) => {
  'from': '2026-03',
  'to': '2026-03',
  'currency': 'EUR',
  'operating_costs_minor': '10501',
  'direct_minor': '0',
  'shared_minor': shared,
  'unallocated_minor': '500',
  'conflicting_lines': 0,
  'resources': [
    for (final (n, minor) in const [(1, '3334'), (2, '3334'), (3, '3333')])
      {
        'resource_kind': 'office',
        'resource_id': 'of-$n',
        'name': 'Office $n',
        'allocated_minor': minor,
        'rules': [
          {'rule_id': 'rule-1', 'revision': 1},
        ],
      },
  ],
  'rules': [
    {
      'rule_id': 'rule-1',
      'revision': 1,
      'basis': 'Floor area',
      'cost_minor': '10001',
      'allocated': true,
    },
  ],
  'quality': const <String>[],
  'reasons': const ['unallocated'],
  'computed_at': '2026-05-02T10:00:00Z',
};

/// March 2026 as pgTAP 246 reads it; the rules saved, kept.
class _Rules implements CostAllocationRepository {
  final saved = <AllocationRuleDraft>[];

  @override
  Future<CostAllocationKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => costAllocationFromJson(_march());

  @override
  Future<List<AllocationRule>> rules(String workspaceId) async => const [];

  @override
  Future<AllocationRule> save(
    String workspaceId, {
    required String? ruleId,
    required int expectedRevision,
    required AllocationRuleDraft draft,
    required String requestId,
  }) async {
    saved.add(draft);
    return AllocationRule(
      ruleId: 'rule-1',
      revision: expectedRevision + 1,
      category: draft.category,
      purchaseLineId: null,
      effectiveFrom: draft.effectiveFrom,
      effectiveTo: null,
      basis: draft.basis,
      weights: draft.weights,
      retired: false,
    );
  }
}
