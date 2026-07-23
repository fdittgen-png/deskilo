// SPDX-License-Identifier: 0BSD
//
// Default profile (#322): with several profiles the user checks ONE as
// the start-up default — the app opens on it at every start, while
// in-session switching still works and lasts until the next start.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

FakeWorkspaceRepository _twoWorkspaces() {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces.add(
    const Workspace(
      id: 'ws-2',
      name: 'Second Space',
      countryCode: 'DE',
      currencyCode: 'EUR',
      timezone: 'Europe/Berlin',
      inviteCode: 'SECOND9999',
    ),
  );
  workspace.extraMyMemberships.add(
    const Member(
      id: 'member-b',
      workspaceId: 'ws-2',
      userId: 'user-1',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    ),
  );
  return workspace;
}

void main() {
  testWidgets(
      'checking the star sets the default; the star fills, radio '
      'semantics move it, re-tap clears it', (tester) async {
    final store = InMemoryDefaultWorkspaceStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: _twoWorkspaces(),
          defaultWorkspace: store,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/profiles');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-default-ws-2')));
    await tester.pumpAndSettle();
    expect(store.value, 'ws-2');

    // Radio semantics: checking the other moves the default.
    await tester.tap(find.byKey(const ValueKey('profile-default-ws-1')));
    await tester.pumpAndSettle();
    expect(store.value, 'ws-1');

    // Re-tapping the checked star clears it (back to last-active).
    await tester.tap(find.byKey(const ValueKey('profile-default-ws-1')));
    await tester.pumpAndSettle();
    expect(store.value, isNull);
  });

  testWidgets(
      'at start-up the checked default wins over the last active profile',
      (tester) async {
    final active = InMemoryActiveWorkspaceStore()..value = 'ws-1';
    final store = InMemoryDefaultWorkspaceStore()..value = 'ws-2';
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: _twoWorkspaces(),
          activeWorkspace: active,
          defaultWorkspace: store,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/profiles');
    await tester.pumpAndSettle();

    // The active check sits on the DEFAULT workspace, not the stored
    // last-active one.
    final row = find.ancestor(
      of: find.text('Second Space'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: row,
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'without a default the last active profile keeps winning (the #89 '
      'behavior)', (tester) async {
    final active = InMemoryActiveWorkspaceStore()..value = 'ws-2';
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: _twoWorkspaces(),
          activeWorkspace: active,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/profiles');
    await tester.pumpAndSettle();

    final row = find.ancestor(
      of: find.text('Second Space'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: row,
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
  });
}
