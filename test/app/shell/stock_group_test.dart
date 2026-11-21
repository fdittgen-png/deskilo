// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4299 -- the Stock group of the navigation, opened as a person does, on a
// phone and on a desk: Items, Places and Stock settings (and the balances and
// the movement log) are reached from the one group below Purchases, and each
// lands on its own page.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/features/stock/presentation/stock_items_screen.dart';
import 'package:deskilo/features/stock/presentation/stock_places_screen.dart';
import 'package:deskilo/features/stock/presentation/stock_settings_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<void> _open(WidgetTester tester, Size size, {Set<WorkspacePermission>? held}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: const {'stockManagement': true, 'purchases': true, 'supplyExpenses': true},
  );
  workspace.myMember = workspace.myMember.copyWith(isOwner: true, isAdmin: true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
        webShellProvider.overrideWithValue(true),
        stockQueriesProvider.overrideWithValue(const DemoStockQueries('ws-1')),
        stockConfigCommandsProvider.overrideWithValue(DemoStockConfigCommands('ws-1')),
        if (held != null) myPermissionsProvider.overrideWithValue(held),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Brings the Stock group's entries into view: the drawer on a phone, the
/// sidebar on a desk.
Future<void> _showGroup(WidgetTester tester, {required bool phone}) async {
  if (phone) {
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
  }
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey('shell-drawer')),
    matching: find.byType(Scrollable),
  );
  final group = _group('stock');
  if (scrollable.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(group, 80, scrollable: scrollable.first);
  }
  if (find.byKey(const ValueKey('drawer-stock-items')).evaluate().isEmpty) {
    await tester.tap(group);
    await tester.pumpAndSettle();
  }
}

/// A drawer group by its id: its tile is keyed `drawer-group-<id>-<active>`.
Finder _group(String id) => find.byWidgetPredicate(
  (w) => w is ExpansionTile && w.key is PageStorageKey && '${(w.key! as PageStorageKey).value}'.startsWith('drawer-group-$id-'),
);

Future<void> _openEntry(WidgetTester tester, String key, Type screen, {required bool phone}) async {
  await _showGroup(tester, phone: phone);
  final entry = find.byKey(ValueKey(key));
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
  expect(find.byType(screen), findsOneWidget, reason: key);
}

void main() {
  const manager = {
    WorkspacePermission.viewStock,
    WorkspacePermission.manageStock,
    WorkspacePermission.manageConfiguration,
    WorkspacePermission.workspaceSettings,
    WorkspacePermission.managePurchases,
    WorkspacePermission.viewFinances,
  };
  for (final (name, size, phone) in [
    ('phone', const Size(390, 844), true),
    ('desk', const Size(1440, 900), false),
  ]) {
    testWidgets('on a $name the Stock group is below Purchases and holds every stock page', (tester) async {
      await _open(tester, size, held: manager);
      await _showGroup(tester, phone: phone);

      for (final key in ['drawer-stock', 'drawer-stock-movements', 'drawer-stock-items', 'drawer-stock-places', 'drawer-stock-settings']) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      final purchases = tester.getTopLeft(_group('purchases')).dy;
      final stock = tester.getTopLeft(_group('stock')).dy;
      expect(stock, greaterThan(purchases), reason: 'Stock is below Purchases');
    });

    for (final (key, screen) in [
      ('drawer-stock-items', StockItemsScreen),
      ('drawer-stock-places', StockPlacesScreen),
      ('drawer-stock-settings', StockSettingsScreen),
    ]) {
      testWidgets('on a $name $key opens its own page', (tester) async {
        await _open(tester, size, held: manager);
        await _openEntry(tester, key, screen, phone: phone);
      });
    }
  }

  testWidgets('a person who may only look finds the pages but not the settings', (tester) async {
    await _open(tester, const Size(390, 844), held: const {WorkspacePermission.viewStock});
    await _showGroup(tester, phone: true);

    expect(find.byKey(const ValueKey('drawer-stock-items')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-stock-places')), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-stock-settings')), findsNothing);
  });
}
