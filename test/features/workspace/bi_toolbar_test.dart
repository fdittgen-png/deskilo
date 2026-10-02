// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 B — the shared Web-BI toolbar drives every module through one
// context in the address: the period, its length, the comparison, the
// grouping and the order reach the server as exactly those intervals and
// groups; the table and the chart print the same figures; an unrecorded
// comparison says so instead of showing 0; a manipulated address reads
// nothing; Back from the source returns to the same analysis.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/presentation/screens/availability_screen.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

typedef _Call = ({DateTime from, DateTime to, String? level});

/// March 2026: total 30/100, level A 20/60, level B 5/30 (5/10 in no
/// current level). February: total 20/80. Before February: not recorded.
class _Kpis implements KpiRepository {
  final calls = <_Call>[];

  @override
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  }) async {
    calls.add((from: from, to: to, level: levelId));
    final march = from.month == 3;
    final (num r, num o) = switch ((march, levelId)) {
      (true, null) => (30, 100),
      (true, 'level-a') => (20, 60),
      (true, _) => (5, 30),
      (false, null) => (20, 80),
      (false, 'level-a') => (10, 50),
      (false, _) => (10, 30),
    };
    final recorded = !from.isBefore(DateTime.utc(2026, 1, 15));
    return seatCapacityFromJson({
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'offered_seat_hours': recorded ? o : 0,
      'reserved_seat_hours': recorded ? r : 0,
      'quality': recorded ? <String>[] : ['not_recorded'],
      'reasons': recorded ? <String>[] : ['history_not_recorded_before'],
      'history_since': '2026-02-01T00:00:00Z',
      'computed_at': '2026-03-15T10:00:00Z',
    });
  }
}

Future<_Kpis> _pump(
  WidgetTester tester, {
  Set<WorkspacePermission>? permissions,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final kpis = _Kpis();
  final plan = FakeFloorPlanRepository()
    ..levels.addAll(const [
      Level(id: 'level-a', workspaceId: 'ws-1', name: 'Ground', sortOrder: 0),
      Level(id: 'level-b', workspaceId: 'ws-1', name: 'First', sortOrder: 1),
    ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {'capacityKpi': true},
          ),
          floorPlan: plan,
          clock: FixedClock(DateTime(2026, 3, 15, 12)),
        ),
        platformIsWebProvider.overrideWithValue(true),
        webShellProvider.overrideWithValue(true),
        kpiRepositoryProvider.overrideWithValue(kpis),
        if (permissions != null)
          myPermissionsProvider.overrideWithValue(permissions),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return kpis;
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

Future<void> _open(WidgetTester tester, String location) async {
  unawaited(_router(tester).push(location));
  await tester.pumpAndSettle();
}

Uri _uri(WidgetTester tester) =>
    GoRouterState.of(tester.element(find.byKey(const ValueKey('bi-page')))).uri;

bool _at(DateTime instant, int year, int month) =>
    instant.isAtSameMomentAs(WorkspaceTime.at(year, month, 1));

Future<void> _choose(WidgetTester tester, String field, String option) async {
  await tester.tap(find.byKey(ValueKey('bi-$field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  testWidgets('the toolbar puts its context in the address and the module '
      'reads exactly those intervals', (tester) async {
    final kpis = await _pump(tester);
    await _open(tester, '/bi');
    expect(_text(tester, 'bi-value'), '30.0%');
    expect(_at(kpis.calls.single.from, 2026, 3), isTrue);
    expect(_at(kpis.calls.single.to, 2026, 4), isTrue);

    kpis.calls.clear();
    await _choose(tester, 'grain', 'Quarter');
    expect(_uri(tester).queryParameters, {'grain': 'quarter'});
    expect(_text(tester, 'bi-period-label'), 'Q1 2026');
    expect(_at(kpis.calls.single.from, 2026, 1), isTrue);
    expect(_at(kpis.calls.single.to, 2026, 4), isTrue);

    kpis.calls.clear();
    await tester.tap(find.byKey(const ValueKey('bi-period-previous')));
    await tester.pumpAndSettle();
    expect(_uri(tester).queryParameters, {'grain': 'quarter', 'at': '-1'});
    expect(_at(kpis.calls.single.from, 2025, 10), isTrue);
  });

  testWidgets('a comparison is worded in percentage points, and the same '
      'figures appear in the table and the chart', (tester) async {
    await _pump(tester);
    await _open(tester, '/bi');
    await _choose(tester, 'comparison', 'The period before');
    expect(_uri(tester).queryParameters, {'cmp': 'previous'});
    expect(_text(tester, 'bi-compared'), 'February 2026: 25.0% (+5.0 pp)');
    expect(find.textContaining('do not offer the same base'), findsOneWidget);
    expect(_text(tester, 'bi-table-total'), '30.0%');
    expect(_text(tester, 'bi-change-total'), '+5.0 pp');

    await tester.tap(find.text('Chart'));
    await tester.pumpAndSettle();
    expect(_uri(tester).queryParameters, {'cmp': 'previous', 'view': 'chart'});
    expect(find.byKey(const ValueKey('bi-table')), findsNothing);
    expect(
      _text(tester, 'bi-chart-total'),
      'Total: 30.0% · February 2026 25.0% (+5.0 pp)',
    );
  });

  testWidgets('a comparison with an unrecorded period is undefined and '
      'says why — never 0', (tester) async {
    await _pump(tester);
    await _open(tester, '/bi?cmp=year');
    expect(_text(tester, 'bi-compared'), 'March 2025: — (—)');
    expect(find.textContaining('March 2025 was not recorded'), findsOneWidget);
    expect(_text(tester, 'bi-change-total'), '—');
  });

  testWidgets('grouping by level reads each level, keeps the total as the '
      'ratio of sums, names the remainder and sorts', (tester) async {
    final kpis = await _pump(tester);
    await _open(tester, '/bi');
    kpis.calls.clear();
    await _choose(tester, 'group', 'Level');
    expect(_uri(tester).queryParameters, {'by': 'level'});
    expect({for (final c in kpis.calls) c.level}, {null, 'level-a', 'level-b'});
    expect(_text(tester, 'bi-table-level-a'), '33.3%');
    expect(_text(tester, 'bi-table-level-b'), '16.7%');
    expect(_text(tester, 'bi-table-remainder'), '50.0%');
    expect(_text(tester, 'bi-table-total'), '30.0%');
    expect(find.text('Not in a current group'), findsOneWidget);

    await _choose(tester, 'sort', 'Lowest first');
    final b = tester.getTopLeft(find.byKey(const ValueKey('bi-table-level-b')));
    final a = tester.getTopLeft(find.byKey(const ValueKey('bi-table-level-a')));
    expect(b.dy, lessThan(a.dy));
  });

  testWidgets('a manipulated address is refused and reads nothing', (
    tester,
  ) async {
    final kpis = await _pump(tester);
    await _open(tester, '/bi?by=member&grain=quarter');
    expect(find.byKey(const ValueKey('bi-invalid-address')), findsOneWidget);
    expect(find.byKey(const ValueKey('bi-toolbar')), findsNothing);
    expect(kpis.calls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('bi-reset')));
    await tester.pumpAndSettle();
    expect(_uri(tester).query, isEmpty);
    expect(kpis.calls, hasLength(1));
  });

  testWidgets('a deep link restores the analysis, and Back from the source '
      'returns to it', (tester) async {
    await _pump(tester);
    await _open(tester, '/bi?grain=year&cmp=previous');
    expect(_text(tester, 'bi-period-label'), '2026');
    await tester.tap(find.byKey(const ValueKey('bi-drill')));
    await tester.pumpAndSettle();
    expect(find.byType(AvailabilityScreen), findsOneWidget);
    _router(tester).pop();
    await tester.pumpAndSettle();
    expect(_uri(tester).queryParameters, {'grain': 'year', 'cmp': 'previous'});
    expect(_text(tester, 'bi-period-label'), '2026');
  });

  testWidgets('a reader without the source right gets the explanation, '
      'not the link', (tester) async {
    await _pump(tester, permissions: {WorkspacePermission.viewAnalytics});
    await _open(tester, '/bi');
    expect(find.byKey(const ValueKey('bi-drill')), findsNothing);
    expect(find.byKey(const ValueKey('bi-drill-restricted')), findsOneWidget);
  });
}
