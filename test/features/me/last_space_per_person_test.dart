// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the last space belongs to ONE person, and leaves with them.
//
// Invariant: the space a person was last in is remembered for that
// person only. Another account signing in on the same device never
// inherits it, and a deliberate sign-out forgets it on the device (the
// server default, `profiles.default_workspace_id`, stays the person's
// own). Before #1823 the key was device-global (`active_workspace_id`)
// and `signOutAndForget` left it behind, so the next person to sign in
// opened in the previous person's space whenever they were a member of
// it too.
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/auth/providers/sign_out.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

FakeWorkspaceRepository _twoSpaces() {
  final repo = FakeWorkspaceRepository.withWorkspace();
  repo.workspaces.add(
    const Workspace(
      id: 'ws-2',
      name: 'Second Space',
      countryCode: 'DE',
      currencyCode: 'EUR',
      timezone: 'Europe/Berlin',
      inviteCode: 'SECOND9999',
    ),
  );
  repo.extraMyMemberships.add(
    const Member(
      id: 'member-b',
      workspaceId: 'ws-2',
      userId: 'user-1',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    ),
  );
  return repo;
}

/// A one-button host so the test signs out the way the app does.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kept alive the way the shell keeps them: the session and the
    // active space are watched for as long as the app runs.
    ref
      ..watch(authStateProvider)
      ..watch(currentWorkspaceProvider);
    return MaterialApp(
        home: Scaffold(
          body: TextButton(
            key: const ValueKey('sign-out'),
            onPressed: () => signOutAndForget(ref),
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeWorkspaceRepository repo,
  required FakeAuthRepository auth,
  InMemoryActiveWorkspaceStore? store,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: repo,
        auth: auth,
        activeWorkspace: store,
      ),
      child: const _Host(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(_Host)));
}

void main() {
  testWidgets(
      'a second person signing in on the same device does not open in '
      'the first person\'s last space', (tester) async {
    final repo = _twoSpaces();
    final auth = FakeAuthRepository.signedIn();
    final container = await _pump(tester, repo: repo, auth: auth);

    await container.read(activeWorkspaceIdProvider.notifier).select('ws-2');
    await tester.pumpAndSettle();
    expect((await container.read(currentWorkspaceProvider.future))?.id,
        'ws-2');

    // Another account takes the device over. Its own server row holds
    // no default: the fake has one slot, and it belonged to user-1.
    repo.serverDefaultWorkspaceId = null;
    auth.signInAs('user-2');
    await tester.pumpAndSettle();

    final chosen = await container.read(activeWorkspaceIdProvider.future);
    expect(chosen, isNot('ws-2'),
        reason: 'user-2 inherited user-1\'s last space');
  });

  testWidgets('signing out forgets the last space on this device',
      (tester) async {
    final repo = _twoSpaces();
    final auth = FakeAuthRepository.signedIn();
    final store = InMemoryActiveWorkspaceStore();
    final container =
        await _pump(tester, repo: repo, auth: auth, store: store);

    await container.read(activeWorkspaceIdProvider.notifier).select('ws-2');
    await tester.pumpAndSettle();
    expect(store.value, 'ws-2');

    await tester.tap(find.byKey(const ValueKey('sign-out')));
    await tester.pumpAndSettle();

    expect(auth.currentUserId, isNull);
    expect(store.value, isNull,
        reason: 'the device still remembers where the last person was');
  });
}
