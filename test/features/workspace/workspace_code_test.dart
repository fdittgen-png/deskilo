// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpWorkspaceCode(WidgetTester tester) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Workspace ID & QR'));
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets('owner sees the workspace QR and the current ID',
      (tester) async {
    await pumpWorkspaceCode(tester);

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('GOODCODE22'), findsOneWidget);
  });

  testWidgets('owner sets a new alphanumeric ID', (tester) async {
    final workspace = await pumpWorkspaceCode(tester);

    await tester.tap(find.text('Change workspace ID'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'KRAFTWERK7');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(workspace.workspaces.single.inviteCode, 'KRAFTWERK7');
    expect(find.text('KRAFTWERK7'), findsOneWidget);
  });

  testWidgets('a too-short ID is rejected with the explanation',
      (tester) async {
    final workspace = await pumpWorkspaceCode(tester);

    await tester.tap(find.text('Change workspace ID'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'AB');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(workspace.workspaces.single.inviteCode, 'GOODCODE22');
    expect(find.textContaining('4–20 letters or digits'), findsOneWidget);
  });

  testWidgets('workers get no workspace-code entry in settings',
      (tester) async {
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

    expect(find.text('Workspace ID & QR'), findsNothing);
  });

  testWidgets('onboarding join mode offers the QR scan button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: FakeWorkspaceRepository(),
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join a workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Scan QR code'), findsOneWidget);
  });
}
