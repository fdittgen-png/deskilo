// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Switching from Me waits for the selected business's effective features,
// opens its supported home, and returns to coworking with either motion
// setting. A later selection supersedes an entry still waiting for features.
import 'dart:async';

import 'package:deskilo/features/reservations/presentation/screens/reserve_screen.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'me_app.dart';

void main() {
  for (final (reducedMotion, delayed, overview) in [
    (false, false, true),
    (true, false, true),
    (false, true, true),
    (true, true, true),
    (true, false, false),
  ]) {
    testWidgets(
      'Me enters the selected place-free business and returns to '
      'coworking (reduced=$reducedMotion, delayed=$delayed, overview=$overview)',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: reducedMotion);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final repo = twoSpaces();
        repo.workspaces[1] = repo.workspaces[1].copyWith(
          featureFlags: {
            ...repo.workspaces.first.featureFlags,
            'placeBooking': false,
            'workspaceOverview': overview,
            if (!overview) 'calendarHub': false,
          },
        );
        final targetReady = Completer<void>();
        final router = await pumpMeApp(
          tester,
          workspace: repo,
          extraOverrides: [
            if (delayed)
              currentWorkspaceProvider.overrideWith((ref) async {
                final id = await ref.watch(activeWorkspaceIdProvider.future);
                if (id == 'ws-2') await targetReady.future;
                return repo.workspaces.firstWhere((space) => space.id == id);
              }),
          ],
        );
        expect(router.state.uri.path, '/reserve');
        await tester.tap(find.byKey(const ValueKey('shell-back-to-me')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('me-space-ws-2')));
        await tester.pumpAndSettle();
        if (delayed) {
          expect(
            router.state.uri.path,
            '/me',
            reason: 'entry waits for the target instead of showing a plan',
          );
          expect(find.byType(ReserveScreen), findsNothing);
          targetReady.complete();
          await tester.pumpAndSettle();
        }
        expect(
          router.state.uri.path,
          overview ? '/workspace-overview' : '/messages',
        );
        expect(find.byType(ReserveScreen), findsNothing);

        await tester.tap(find.byKey(const ValueKey('shell-back-to-me')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('me-space-ws-1')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/reserve');
        expect(find.byType(ReserveScreen), findsOneWidget);
      },
    );
  }

  testWidgets('a delayed Me entry cannot replace a later selection', (
    tester,
  ) async {
    final repo = twoSpaces();
    final targetReady = Completer<void>();
    final router = await pumpMeApp(
      tester,
      workspace: repo,
      extraOverrides: [
        currentWorkspaceProvider.overrideWith((ref) async {
          final id = await ref.watch(activeWorkspaceIdProvider.future);
          if (id == 'ws-2') await targetReady.future;
          return repo.workspaces.firstWhere((space) => space.id == id);
        }),
      ],
    );
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
}
