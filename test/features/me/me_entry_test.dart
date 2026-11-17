// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — opening the app: signed in with a last space of THIS person's,
// the app opens in it; with none, it opens on Me. A second person who
// signs in on the same device never opens in the first person's space.
// Me entry waits for the selected business's effective features, opens its
// supported home, and returns to coworking with either motion setting.
import 'dart:async';

import 'package:deskilo/app/shell/shell_screen.dart';
import 'package:deskilo/features/reservations/presentation/screens/reserve_screen.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

void main() {
  for (final (reducedMotion, delayed, overview) in [
    (false, false, true),
    (true, false, true),
    (false, true, true),
    (true, true, true),
    (true, false, false),
  ]) {
    testWidgets('Me enters the selected place-free business and returns to '
        'coworking (reduced=$reducedMotion, delayed=$delayed, overview=$overview)', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: reducedMotion);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final repo = twoSpaces();
      repo.workspaces[1] = repo.workspaces[1].copyWith(featureFlags: {
        ...repo.workspaces.first.featureFlags,
        'placeBooking': false,
        'workspaceOverview': overview,
        if (!overview) 'calendarHub': false,
      });
      final targetReady = Completer<void>();
      final router = await pumpMeApp(tester, workspace: repo,
          extraOverrides: [
        if (delayed)
          currentWorkspaceProvider.overrideWith((ref) async {
            final id = await ref.watch(activeWorkspaceIdProvider.future);
            if (id == 'ws-2') await targetReady.future;
            return repo.workspaces.firstWhere((space) => space.id == id);
          }),
      ]);
      expect(router.state.uri.path, '/reserve');
      await tester.tap(find.byKey(const ValueKey('shell-back-to-me')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('me-space-ws-2')));
      await tester.pumpAndSettle();
      if (delayed) {
        expect(router.state.uri.path, '/me',
            reason: 'entry waits for the target instead of showing a plan');
        expect(find.byType(ReserveScreen), findsNothing);
        targetReady.complete();
        await tester.pumpAndSettle();
      }
      expect(router.state.uri.path,
          overview ? '/workspace-overview' : '/messages');
      expect(find.byType(ReserveScreen), findsNothing);

      await tester.tap(find.byKey(const ValueKey('shell-back-to-me')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('me-space-ws-1')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/reserve');
      expect(find.byType(ReserveScreen), findsOneWidget);
    });
  }

  testWidgets('a delayed Me entry cannot replace a later selection',
      (tester) async {
    final repo = twoSpaces();
    final targetReady = Completer<void>();
    final router = await pumpMeApp(tester, workspace: repo, extraOverrides: [
      currentWorkspaceProvider.overrideWith((ref) async {
        final id = await ref.watch(activeWorkspaceIdProvider.future);
        if (id == 'ws-2') await targetReady.future;
        return repo.workspaces.firstWhere((space) => space.id == id);
      }),
    ]);
    await tester.tap(find.byKey(const ValueKey('shell-back-to-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-space-ws-2')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me');
    await tester.tap(find.byKey(const ValueKey('me-space-ws-1')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/reserve');
    targetReady.complete();
    await tester.pump();
    expect(find.byKey(const ValueKey('space-entry-curtain')), findsNothing);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/reserve');
  });

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
