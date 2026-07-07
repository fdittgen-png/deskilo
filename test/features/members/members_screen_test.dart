// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpMembers(WidgetTester tester) async {
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..otherMembers.add(
      const Member(
        id: 'member-2',
        workspaceId: 'ws-1',
        userId: 'user-2',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      ),
    );
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Members & plans'));
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets('owner reaches the members screen and sees roles',
      (tester) async {
    await pumpMembers(tester);

    expect(find.text('Flo'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
  });

  testWidgets('assigning a plan updates the member', (tester) async {
    final workspace = await pumpMembers(tester);

    // Ana's dropdown is the second one.
    await tester.tap(find.text('No plan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Half').last);
    await tester.pumpAndSettle();

    expect(workspace.otherMembers.single.planId, 'plan-half');
  });

  testWidgets('long-press pauses an active membership', (tester) async {
    final workspace = await pumpMembers(tester);

    await tester.longPress(find.text('Ana'));
    await tester.pumpAndSettle();

    expect(workspace.otherMembers.single.status, MemberStatus.paused);
  });

  testWidgets('workers have no members entry in settings', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..myMember = const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Members & plans'), findsNothing);
  });
}
