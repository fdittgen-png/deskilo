// SPDX-License-Identifier: AGPL-3.0-or-later
// Me destination actions update the real route, direct links restore the
// selected destination, and history changes retain visited inbox state.
import 'package:deskilo/features/me/presentation/me_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'me_app.dart';
import '../../helpers/mock_providers.dart';

void main() {
  testWidgets(
    'navigation and avatar update the URL; history preserves the inbox filter',
    (tester) async {
      final router = await pumpMeApp(
        tester,
        workspace: FakeWorkspaceRepository(workspaces: []),
      );
      for (final tab in ['discover', 'messages']) {
        await tester.tap(find.byKey(ValueKey('me-tab-$tab')));
        await tester.pumpAndSettle();
        expect(router.state.uri.queryParameters['tab'], tab);
      }
      await tester.tap(find.byKey(const ValueKey('unified-inbox-unread')));
      await tester.pumpAndSettle();
      final messages = router.state.uri;
      await tester.tap(find.byKey(const ValueKey('me-profile-settings')));
      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters['tab'], 'me');
      final profile = router.state.uri;
      await router.routeInformationProvider.didPushRouteInformation(
        RouteInformation(uri: messages),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey('unified-inbox-unread')),
            )
            .selected,
        isTrue,
      );
      await router.routeInformationProvider.didPushRouteInformation(
        RouteInformation(uri: profile),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('me-account-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final tab in MeTab.values) {
    testWidgets('direct link restores ${tab.wire} after app startup', (
      tester,
    ) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/me?tab=${tab.wire}';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      final router = await pumpMeApp(
        tester,
        workspace: FakeWorkspaceRepository(workspaces: []),
      );
      expect(router.state.uri.queryParameters['tab'], tab.wire);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        tab.index,
      );
    });
  }

  testWidgets('an invalid destination predictably opens Home', (tester) async {
    final router = await pumpMeApp(
      tester,
      workspace: FakeWorkspaceRepository(workspaces: []),
    );
    await goTo(tester, router, '/me?tab=unknown');
    expect(find.byKey(const ValueKey('me-home-empty')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });
}
