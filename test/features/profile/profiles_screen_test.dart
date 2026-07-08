// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<(FakeWorkspaceRepository, InMemoryActiveWorkspaceStore)> pumpProfiles(
  WidgetTester tester,
) async {
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..workspaces.add(
      const Workspace(
        id: 'ws-2',
        name: 'Beach Hub',
        countryCode: 'ES',
        currencyCode: 'EUR',
        timezone: 'Europe/Madrid',
        inviteCode: 'BEACHHUB1',
      ),
    )
    ..extraMyMemberships.add(
      const Member(
        id: 'member-9',
        workspaceId: 'ws-2',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      ),
    );
  final store = InMemoryActiveWorkspaceStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: workspace,
        activeWorkspace: store,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Profiles'));
  await tester.pumpAndSettle();
  return (workspace, store);
}

void main() {
  testWidgets('profiles list shows each membership with its role',
      (tester) async {
    await pumpProfiles(tester);

    expect(find.text('Test Space'), findsOneWidget);
    expect(find.text('Beach Hub'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    // First workspace is active by default.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping a profile switches and persists the active workspace',
      (tester) async {
    final (_, store) = await pumpProfiles(tester);

    await tester.tap(find.text('Beach Hub'));
    await tester.pumpAndSettle();

    expect(store.value, 'ws-2');
    // The check mark moved to the Beach Hub card.
    final checkFinder = find.descendant(
      of: find.widgetWithText(Card, 'Beach Hub'),
      matching: find.byIcon(Icons.check_circle),
    );
    expect(checkFinder, findsOneWidget);
  });

  testWidgets('a persisted choice survives a restart', (tester) async {
    final store = InMemoryActiveWorkspaceStore()..value = 'ws-2';
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..workspaces.add(
        const Workspace(
          id: 'ws-2',
          name: 'Beach Hub',
          countryCode: 'ES',
          currencyCode: 'EUR',
          timezone: 'Europe/Madrid',
          inviteCode: 'BEACHHUB1',
        ),
      )
      ..extraMyMemberships.add(
        const Member(
          id: 'member-9',
          workspaceId: 'ws-2',
          userId: 'user-1',
          isAdmin: false,
          isOwner: false,
          status: MemberStatus.active,
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: workspace,
          activeWorkspace: store,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Worker profile in ws-2 → no owner affordances on the Plan tab.
    expect(find.byIcon(Icons.design_services_outlined), findsNothing);
  });

  testWidgets('add-a-profile leads to the create/join screen',
      (tester) async {
    await pumpProfiles(tester);

    await tester.tap(find.text('Add a profile'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to DesKilo'), findsOneWidget);
  });
}
