// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — Me is the account's own home: with ZERO workspaces the app
// opens there, and every one of its four tabs opens. Each affordance on
// Home and on the Me tab is tapped and lands where it says.
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/me/presentation/me_messages_tab.dart';
import 'package:deskilo/features/me/presentation/me_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

void main() {
  testWidgets('zero workspaces: Me opens from the first run, and every tab '
      'opens', (tester) async {
    final router = await pumpMeApp(
      tester,
      workspace: FakeWorkspaceRepository(workspaces: []),
    );
    // The first run creates or joins a space; Me is in its account menu.
    expect(router.state.uri.path, '/onboarding');
    await tester.tap(find.byIcon(Icons.public).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portal-open-me')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me');
    expect(find.byType(MeShell), findsOneWidget);
    expect(find.byKey(const ValueKey('me-home-empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-tab-discover')));
    await tester.pumpAndSettle();
    expect(find.byType(DirectoryScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-tab-messages')));
    await tester.pumpAndSettle();
    expect(find.byType(MeMessagesTab), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-tab-me')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-visibility-card')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-tab-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-home-empty')), findsOneWidget);
    expect(router.state.uri.path, '/me',
        reason: 'no tab of Me asks for a workspace');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home offers finding, joining and creating a space',
      (tester) async {
    final router = await pumpMeApp(
      tester,
      workspace: FakeWorkspaceRepository(workspaces: []),
    );
    await goTo(tester, router, '/me');
    await tester.tap(find.byKey(const ValueKey('me-home-discover')));
    await tester.pumpAndSettle();
    expect(find.byType(DirectoryScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-tab-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-home-join')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/onboarding?join=1');

    await goTo(tester, router, '/me');
    await tester.tap(find.byKey(const ValueKey('me-home-create')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/onboarding');
  });

  testWidgets('with spaces, Home lists them, last used first, and opens the '
      'detailed list', (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces(serverDefault: 'ws-2'));
    await goTo(tester, router, '/me');
    final first = tester.getTopLeft(find.byKey(const ValueKey('me-space-ws-2')));
    final second = tester.getTopLeft(find.byKey(const ValueKey('me-space-ws-1')));
    expect(first.dy, lessThan(second.dy), reason: 'the last used space leads');
    expect(find.byKey(const ValueKey('me-space-last-ws-2')), findsOneWidget);
    await tapIn(tester, 'me-home-list', find.byKey(const ValueKey('me-home-manage')));
    expect(router.state.uri.path, '/profiles');
  });

  for (final (key, path) in [
    ('me-activity', '/account-activity'),
    ('me-privacy', '/privacy'),
    ('me-servers', '/connections'),
    ('me-help', '/help'),
    ('settings-linked-accounts', '/linked-accounts'),
  ]) {
    testWidgets('the Me tab opens $path', (tester) async {
      final router = await pumpMeApp(tester);
      await goTo(tester, router, '/me?tab=me');
      await tapIn(tester, 'me-account-list', find.byKey(ValueKey(key)));
      expect(router.state.uri.path, path);
    });
  }

  testWidgets('the Me tab signs out', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    final router = await pumpMeApp(tester, auth: auth);
    await goTo(tester, router, '/me?tab=me');
    await tapIn(tester, 'me-account-list', find.byKey(const ValueKey('me-sign-out')));
    expect(auth.currentUserId, isNull);
    expect(router.state.uri.path, '/auth');
  });
}
