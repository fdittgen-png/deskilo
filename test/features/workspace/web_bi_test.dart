// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 A — the Web-BI area: a drawer entry and a /bi page on the web
// build only, showing the registered modules this reader may see; a
// native app (even with the menu chosen) has neither, and a direct link
// is turned away before anything is fetched.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

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
    return seatCapacityFromJson({
      ..._capacityFields,
      'from': '2026-10-01T00:00:00Z',
      'to': '2026-11-01T00:00:00Z',
      'offered_seat_hours': 100,
      'reserved_seat_hours': 25,
      'computed_at': '2026-10-01T10:00:00Z',
    });
  }
}

Future<_Kpis> _pump(
  WidgetTester tester, {
  required bool web,
  bool on = true,
  bool menu = true,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final kpis = _Kpis();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {'capacityKpi': on},
          ),
        ),
        platformIsWebProvider.overrideWithValue(web),
        webShellProvider.overrideWithValue(menu),
        kpiRepositoryProvider.overrideWithValue(kpis),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return kpis;
}

Future<void> _go(WidgetTester tester, String path) async {
  unawaited(
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path),
  );
  await tester.pumpAndSettle();
}

Future<bool> _drawerHas(WidgetTester tester, String key) async {
  final menu = find.byTooltip('Open navigation menu');
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }
  final scrollable = find.descendant(
    of: find.byType(ShellDrawer),
    matching: find.byType(Scrollable),
  );
  // #2313 — the BI lives in the Reporting group.
  final group = find.byKey(const PageStorageKey('drawer-group-reporting-false'));
  if (group.evaluate().isNotEmpty) {
    await tester.ensureVisible(group);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: group, matching: find.byType(ListTile)).first);
    await tester.pumpAndSettle();
  }
  try {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(key)),
      80,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    return true;
  } on StateError {
    return false;
  }
}

void main() {
  test('only the modules the reader may see, and the web only', () {
    final all = WorkspaceFeature.values.toSet();
    expect(
      visibleBiModules(all, {WorkspacePermission.viewAnalytics}),
      hasLength(1),
    );
    expect(visibleBiModules(all, const {}), isEmpty);
    expect(
      biAvailable(
        features: all,
        permissions: {WorkspacePermission.viewAnalytics},
      ),
      isTrue,
    );
  });

  testWidgets('web: visible navigation opens BI, which shows the capacity module', (
    tester,
  ) async {
    final kpis = await _pump(tester, web: true);
    expect(await _drawerHas(tester, 'drawer-bi'), isTrue);
    await tester.tap(find.byKey(const ValueKey('drawer-bi')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bi-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('bi-area-capacity')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bi-area-finance')),
      findsNothing,
      reason: 'an area without a module is not shown',
    );
    expect(
      find.byKey(const ValueKey('bi-module-capacity.seat_utilisation')),
      findsOneWidget,
    );
    expect(kpis.calls, greaterThan(0));
  });

  testWidgets('native with the menu chosen: the entry is there and opens BI', (
    tester,
  ) async {
    final kpis = await _pump(tester, web: false);
    expect(await _drawerHas(tester, 'drawer-bi'), isTrue);
    await tester.tap(find.byKey(const ValueKey('drawer-bi')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bi-page')), findsOneWidget);
    expect(kpis.calls, greaterThan(0));
  });

  testWidgets('web with no module (feature off): no entry, no page', (
    tester,
  ) async {
    final kpis = await _pump(tester, web: true, on: false);
    await _go(tester, '/bi');
    expect(find.byKey(const ValueKey('bi-page')), findsNothing);
    expect(kpis.calls, 0);
  });
}

const _capacityFields = <String, dynamic>{
  'seats': 0,
  'physical_seat_hours': 0,
  'offered_seat_hours': 0,
  'reserved_seat_hours': 0,
  'reserved_outside_offered_seat_hours': 0,
  'overlapping_seat_hours': 0,
  'rooms_without_seats': 0,
  'offered_room_hours': 0,
  'reserved_room_hours': 0,
  'quality': <String>[],
  'reasons': <String>[],
};
