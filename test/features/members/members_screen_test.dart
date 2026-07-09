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
  testWidgets('owner reaches the members screen and sees roles + levels',
      (tester) async {
    await pumpMembers(tester);

    expect(find.text('Flo'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    // Both members hold the migrated default of 100%.
    expect(find.text('100%'), findsNWidgets(2));
  });

  testWidgets('picking an offered level updates the member (#128)',
      (tester) async {
    final workspace = await pumpMembers(tester);

    // Ana's row is the second one.
    await tester.tap(find.byIcon(Icons.percent).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('50%').last);
    await tester.pumpAndSettle();

    expect(workspace.otherMembers.single.subscriptionPct, 50);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('the owner can assign a negotiated custom percentage',
      (tester) async {
    final workspace = await pumpMembers(tester);

    await tester.tap(find.byIcon(Icons.percent).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Custom (1–100)'),
      '37',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(workspace.otherMembers.single.subscriptionPct, 37);
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
