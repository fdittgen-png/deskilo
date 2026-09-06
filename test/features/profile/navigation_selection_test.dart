// SPDX-License-Identifier: 0BSD
//
// #969 — the Navigation tile beside the theme: choosing the menu swaps
// the bottom bar for the drawer at once; the web never sees the tile.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_pref_stores.dart';
import '../../helpers/mock_providers.dart';

Future<void> _pump(WidgetTester tester,
    {required bool web, required InMemoryNavigationStyleStore store}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(navigationStyle: store),
        platformIsWebProvider.overrideWithValue(web),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 80,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('native: the tile reads the default; choosing Menu persists '
      'and the shell shows the drawer instead of the bar', (tester) async {
    final store = InMemoryNavigationStyleStore();
    await _pump(tester, web: false, store: store);
    expect(find.byType(ShellBottomBar), findsOneWidget);
    await _openSettings(tester);

    final tile = find.byKey(const ValueKey('settings-navigation'));
    await _reveal(tester, tile);
    expect(find.text('Default for this device'), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-menu')));
    await tester.pumpAndSettle();

    expect(store.style, 'menu');
    expect(find.text('Menu: the hamburger, like the web'), findsOneWidget);

    // Back on the shell: the bar is gone, the hamburger is there.
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(find.byType(ShellBottomBar), findsNothing,
        reason: 'the bar is gone the moment the choice is made');
    expect(find.byTooltip('Open navigation menu'), findsOneWidget,
        reason: 'the hamburger is there instead');
  });

  testWidgets('the web never offers the choice', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pump(tester, web: true, store: InMemoryNavigationStyleStore());
    expect(find.byType(ShellBottomBar), findsNothing);
    await _openSettings(tester);
    await _reveal(tester, find.text('Theme'));
    expect(find.byKey(const ValueKey('settings-navigation')), findsNothing);
  });
}
