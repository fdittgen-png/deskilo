// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — two design languages, one app. A space wears its brand colour
// and, when it is a development space, the #917 strip; Me wears
// DesKilo's ink-blue and neither — also on the pages pushed from it. In
// the space, the chip names it and switches, and the avatar goes back to
// Me; entering a space is a visible curtain unless motion is off.
import 'package:deskilo/app/shell/shell_screen.dart';
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/features/me/presentation/me_shell.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _brand = 0xFFB0413E;

FakeWorkspaceRepository _brandedDevSpace() {
  final repo = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {'workspaceBranding': true},
  );
  repo.workspaces[0] = repo.workspaces[0].copyWith(
    branding: {'seed_color': '#B0413E'},
    environment: 'dev',
  );
  return repo;
}

Color _primaryAt(WidgetTester tester, Finder finder) =>
    Theme.of(tester.element(finder)).colorScheme.primary;

void main() {
  testWidgets('a space shows its brand and its strip; Me shows neither, '
      'on its own screens and on the pages pushed from it', (tester) async {
    final router = await pumpMeApp(tester, workspace: _brandedDevSpace());
    final brand = DeskiloTheme.light(brand: const Color(_brand)).colorScheme.primary;
    final ink = DeskiloTheme.light(brand: DeskiloTheme.meLayerSeed).colorScheme.primary;
    expect(brand, isNot(ink));

    expect(router.state.uri.path, '/reserve');
    expect(find.byKey(const ValueKey('development-banner')), findsOneWidget);
    expect(_primaryAt(tester, find.byType(ShellScreen)), brand);

    await tester.tap(find.byKey(const ValueKey('shell-back-to-me')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me');
    expect(find.byKey(const ValueKey('development-banner')), findsNothing);
    expect(_primaryAt(tester, find.byType(MeShell)), ink);

    await pushTo(tester, router, '/linked-accounts');
    expect(find.byKey(const ValueKey('development-banner')), findsNothing);
    expect(_primaryAt(tester, find.byType(Scaffold).last), ink);

    await goTo(tester, router, '/reserve');
    expect(find.byKey(const ValueKey('development-banner')), findsOneWidget);
    expect(_primaryAt(tester, find.byType(ShellScreen)), brand);
  });

  testWidgets('the chip names the space and switches; its first row goes '
      'back to Me', (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces());
    expect(find.descendant(
        of: find.byKey(const ValueKey('space-chip')),
        matching: find.text('Test Space')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('space-chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('space-switcher-ws-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('space-switcher-ws-2')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(ShellScreen)));
    expect(container.read(currentWorkspaceProvider).value?.id, 'ws-2');
    expect(find.descendant(
        of: find.byKey(const ValueKey('space-chip')),
        matching: find.text('Second Space')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('space-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('space-switcher-back-to-me')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me');
  });

  testWidgets('entering a space from Me is a visible curtain, then the space',
      (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces());
    await goTo(tester, router, '/me');
    await tester.tap(find.text('Second Space'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const ValueKey('space-entry-curtain')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('space-entry-curtain')), findsNothing);
    expect(router.state.uri.path, '/reserve');
    final container = ProviderScope.containerOf(tester.element(find.byType(ShellScreen)));
    expect(container.read(currentWorkspaceProvider).value?.id, 'ws-2');
  });

  testWidgets('with reduced motion there is no curtain: the space opens',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final router = await pumpMeApp(tester, workspace: twoSpaces());
    await goTo(tester, router, '/me');
    await tester.tap(find.text('Second Space'));
    await tester.pump();
    expect(find.byKey(const ValueKey('space-entry-curtain')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('space-entry-curtain')), findsNothing);
    expect(router.state.uri.path, '/reserve');
  });
}
