// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2580 C2 — what narrows a report, from the editor's own controls: a floor
// picked on a bar is kept for the whole report or for one visual alone, each
// shown where it applies and saved with the report; a visual's source opens
// the bookings of that floor only, and can be switched off. #2579: the grid
// at a wide, a medium and a compact width with twice the text keeps every
// visual and its reading order, and asks nothing again.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_saved_view.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

/// Every read: level A 20/60, any other level 5/30, the whole 30/100.
class _Kpis implements KpiRepository {
  int calls = 0;

  @override
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  }) async {
    calls++;
    final (num r, num o) = switch (levelId) {
      null => (30, 100),
      'level-a' => (20, 60),
      _ => (5, 30),
    };
    return seatCapacityFromJson({
      'seats': 0,
      'physical_seat_hours': 0,
      'reserved_outside_offered_seat_hours': 0,
      'overlapping_seat_hours': 0,
      'rooms_without_seats': 0,
      'offered_room_hours': 0,
      'reserved_room_hours': 0,
      'reasons': <String>[],
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'offered_seat_hours': o,
      'reserved_seat_hours': r,
      'quality': <String>[],
      'history_since': '2025-01-01T00:00:00Z',
      'computed_at': '2026-03-15T10:00:00Z',
    });
  }
}

const _capacity = 'capacity.seat_utilisation';

/// One page: a capacity figure and the same figure as a floor bar.
BiReportDefinition _report() => BiReportDefinition(
  period: const BiReportPeriod.relative(BiGrain.month, 0),
  pages: [
    BiReportPage(
      id: 'p1',
      title: 'Capacity',
      visuals: [
        BiReportVisual.kpi(
          id: 'v1',
          metricId: _capacity,
          layout: const BiVisualLayout(order: 0, span: 3, height: 1),
        ),
        BiReportVisual.kpi(
          id: 'v2',
          metricId: _capacity,
          layout: const BiVisualLayout(order: 1),
        ).copyWith(type: BiVisualType.bar).withDimension('level'),
      ],
    ),
  ],
);

Future<String> _pumpEditor(
  WidgetTester tester,
  InMemoryBiViewRepository views, {
  _Kpis? kpis,
}) async {
  final id = (await views.save(
    'ws-1',
    scope: BiViewScope.private,
    name: 'Mine',
    definition: BiViewDefinition.ofReport(_report()),
    expectedRevision: 0,
  )).id;
  tester.view.physicalSize = const Size(1400, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
            featureFlags: {'capacityKpi': true, 'biReportDesigner': true},
          ),
          floorPlan: plan,
          clock: FixedClock(DateTime(2026, 3, 15, 12)),
          biViews: views,
        ),
        platformIsWebProvider.overrideWithValue(true),
        webShellProvider.overrideWithValue(true),
        kpiRepositoryProvider.overrideWithValue(kpis ?? _Kpis()),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).push('/bi/report/$id'),
  );
  await tester.pumpAndSettle();
  return id;
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)).first);
  await tester.tap(find.byKey(ValueKey(key)).first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last));

void main() {
  testWidgets('a floor picked on the bar is kept for the whole report, '
      'named in the filter pane and saved', (tester) async {
    final views = InMemoryBiViewRepository();
    await _pumpEditor(tester, views);
    expect(find.byKey(const ValueKey('bi-filter-none')), findsOneWidget);

    await _tap(tester, 'bi-bar-v2-level-a');
    expect(find.byKey(const ValueKey('bi-selection-chip')), findsOneWidget);
    await _tap(tester, 'bi-selection-keep-report');

    expect(find.byKey(const ValueKey('bi-selection-chip')), findsNothing);
    final chip = find.byKey(const ValueKey('bi-filter-report-0'));
    expect(chip, findsOneWidget);
    expect(
      find.descendant(of: chip, matching: find.textContaining('Ground')),
      findsOneWidget,
      reason: 'the floor is named, never its id',
    );

    await _tap(tester, 'bi-editor-save');
    final saved = (await views.list('ws-1')).single.definition!.report!;
    expect(saved.filters.single.toJson(), {
      'dimension': 'level',
      'operator': 'eq',
      'value': 'level-a',
    });
    expect(saved.pages.single.filters, isEmpty);

    await _tap(tester, 'bi-editor-undo');
    expect(find.byKey(const ValueKey('bi-filter-report-0')), findsNothing);
  });

  testWidgets('one visual keeps the floor alone; its source opens that '
      'floor\'s bookings and can be switched off', (tester) async {
    final views = InMemoryBiViewRepository();
    await _pumpEditor(tester, views);

    await _tap(tester, 'bi-visual-select-v1');
    expect(find.byKey(const ValueKey('bi-prop-filters-none-v1')), findsOne);
    await _tap(tester, 'bi-bar-v2-level-a');
    await _tap(tester, 'bi-prop-keep-selection-v1');

    expect(find.byKey(const ValueKey('bi-selection-chip')), findsNothing);
    expect(find.byKey(const ValueKey('bi-filter-none')), findsOneWidget);
    expect(find.byKey(const ValueKey('bi-prop-filter-v1-0')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('bi-visual-value-v1')))
          .data,
      '33.3%',
      reason: 'the figure answers level A alone: 20/60',
    );

    await _tap(tester, 'bi-visual-drill-v1');
    expect(
      _router(tester).state.uri.toString(),
      '/reservations/period?from=2026-03&to=2026-03&level=level-a',
    );
    expect(find.text('On Ground only'), findsOneWidget);
    _router(tester).pop();
    await tester.pumpAndSettle();

    await _tap(tester, 'bi-visual-select-v1');
    await _tap(tester, 'bi-prop-drill-v1');
    expect(find.byKey(const ValueKey('bi-visual-drill-v1')), findsNothing);
    expect(
      find.byKey(const ValueKey('bi-visual-drill-v2')),
      findsOneWidget,
      reason: 'the other visual still offers its source',
    );
    await _tap(tester, 'bi-editor-save');
    final saved = (await views.list('ws-1')).single.definition!.report!;
    final v1 = saved.pages.single.visuals.firstWhere((v) => v.id == 'v1');
    expect(v1.drills, isFalse);
    expect(v1.filters.single.value, 'level-a');

    await _tap(tester, 'bi-visual-select-v1');
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('bi-prop-filter-v1-0')),
        matching: find.byType(Icon),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bi-prop-filters-none-v1')), findsOne);
  });

  testWidgets('wide, medium and compact with twice the text: every visual '
      'in its reading order, and nothing is asked again', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final kpis = _Kpis();
    await _pumpEditor(tester, InMemoryBiViewRepository(), kpis: kpis);
    await _tap(tester, 'bi-editor-preview');
    final asked = kpis.calls;
    expect(asked, greaterThan(0));
    for (final width in [1400.0, 700.0, 360.0]) {
      tester.view.physicalSize = Size(width, 2600);
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(
        find.byKey(const ValueKey('bi-visual-v1')),
      );
      final second = tester.getTopLeft(
        find.byKey(const ValueKey('bi-visual-v2')),
      );
      expect(
        first.dy < second.dy || (first.dy == second.dy && first.dx < second.dx),
        isTrue,
        reason: 'at $width px the first visual still reads first',
      );
      expect(tester.takeException(), isNull, reason: 'no overflow at $width');
    }
    expect(kpis.calls, asked, reason: 'a layout change reads nothing');
  });
}
