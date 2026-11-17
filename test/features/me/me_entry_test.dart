// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — opening the app: signed in with a last space of THIS person's,
// the app opens in it; with none, it opens on Me. A second person who
// signs in on the same device never opens in the first person's space.
import 'package:deskilo/app/shell/shell_screen.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

void main() {
  testWidgets('the app opens in the last space of the signed-in person',
      (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces(serverDefault: 'ws-2'));
    expect(router.state.uri.path, '/reserve');
    final container = ProviderScope.containerOf(tester.element(find.byType(ShellScreen)));
    expect(container.read(currentWorkspaceProvider).value?.id, 'ws-2');
  });

  testWidgets('with no space of theirs to return to, the app opens on Me',
      (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces(serverDefault: null));
    expect(router.state.uri.path, '/me');
  });

  testWidgets('sign out, then another person signs in: never the first '
      'person\'s space', (tester) async {
    final repo = twoSpaces();
    final auth = FakeAuthRepository.signedIn();
    final router = await pumpMeApp(tester, workspace: repo, auth: auth);
    expect(router.state.uri.path, '/reserve');

    // user-1 moves to ws-2 in this session: the device remembers it.
    await tester.tap(find.byKey(const ValueKey('shell-back-to-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-space-ws-2')));
    await tester.pumpAndSettle();
    final ref = ProviderScope.containerOf(tester.element(find.byType(ShellScreen)));
    expect(ref.read(currentWorkspaceProvider).value?.id, 'ws-2');
    // Signing out the way the person does: Me › Me › Sign out.
    await tester.tap(find.byKey(const ValueKey('shell-back-to-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-profile-settings')));
    await tester.pumpAndSettle();
    await tapIn(tester, 'me-account-list', find.byKey(const ValueKey('me-sign-out')));
    expect(router.state.uri.path, '/auth');

    // user-2 is a member of both spaces too, and chose none of them yet.
    repo.serverDefaultWorkspaceId = null;
    auth.signInAs('user-2');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me',
        reason: 'user-2 opened in user-1\'s last space');
  });
}
