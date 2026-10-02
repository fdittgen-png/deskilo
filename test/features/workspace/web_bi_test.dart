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
    return seatCapacityFromJson(const {
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
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey('shell-drawer')),
    matching: find.byType(Scrollable),
  );
  try {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(key)),
      80,
      scrollable: scrollable,
    );
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
        platformIsWeb: false,
        features: all,
        permissions: {WorkspacePermission.viewAnalytics},
      ),
      isFalse,
    );
  });

  testWidgets('web: the drawer opens BI, which shows the capacity module', (
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
    expect(find.byKey(const ValueKey('capacity-kpi-card')), findsOneWidget);
    expect(kpis.calls, greaterThan(0));
  });

  testWidgets('native with the menu chosen: no entry, and a direct link is '
      'turned away without a fetch', (tester) async {
    final kpis = await _pump(tester, web: false);
    expect(await _drawerHas(tester, 'drawer-bi'), isFalse);
    await tester.tapAt(const Offset(1150, 800)); // close the drawer
    await tester.pumpAndSettle();
    await _go(tester, '/bi');
    expect(find.byKey(const ValueKey('bi-page')), findsNothing);
    expect(kpis.calls, 0);
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
