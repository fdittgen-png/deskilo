// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — the desk's keyboard guard (F4) on the search window: opened with
// Ctrl+K over /invoices at 1024, 1440 and 1920 and holding results, Tab
// reaches each of its stops once and nothing in it is out of every key's
// reach; Escape closes it. With SHEET=1 it writes its sheets: the window
// at 1440, and at 390 the narrow shell's drawer, whose first entry opens
// search (docs/testing/desk-guards.md).
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/features/search/presentation/search_palette.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_money_repository.dart';
import '../helpers/mock_providers.dart';
import 'experience_guards.dart';

Future<void> _open(WidgetTester tester, Size size, {bool menu = false}) async {
  final features = WorkspaceFeature.values.toSet();
  final money = FakeMoneyRepository();
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: kTestPeriod,
  );
  await pumpRoute(
    tester,
    menu ? '/money' : '/invoices',
    size: size,
    overrides: [
      ...standardTestOverrides(
        money: money,
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: {for (final f in features) f.name: true},
        ),
      ),
      enabledFeaturesSyncProvider.overrideWithValue(features),
      if (menu) webShellProvider.overrideWithValue(true),
    ],
  );
}

Future<void> _search(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('search-field')), 'in');
  await tester.pump(searchDebounce);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => loadSheetFonts(always: true));

  for (final size in deskGuardSizes) {
    testWidgets('the search window at ${size.width.toInt()}: every control '
        'within a key\'s reach; Escape closes it', (tester) async {
      await _open(tester, size);
      await _search(tester);
      expect(find.byKey(const ValueKey('search-palette')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('search-palette')),
          matching: find.byType(ListTile),
        ),
        findsWidgets,
      );
      expect(
        await keyboardProblems(
          tester,
          within: find.byKey(const ValueKey('search-palette')),
        ),
        isEmpty,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('search-palette')), findsNothing);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('search sheet at 1440, ${brightness.name}', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _open(tester, const Size(1440, 900));
      await _search(tester);
      await writeDeskSheet(
        tester,
        module: 'search',
        screen: 'window',
        width: 1440,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('search sheet at 390 (the drawer\'s entry), '
        '${brightness.name}', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _open(tester, const Size(390, 844), menu: true);
      tester
          .stateList<ScaffoldState>(find.byType(Scaffold))
          .firstWhere((s) => s.hasDrawer)
          .openDrawer();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('drawer-search')), findsOneWidget);
      await writeDeskSheet(
        tester,
        module: 'search',
        screen: 'drawer',
        width: 390,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
