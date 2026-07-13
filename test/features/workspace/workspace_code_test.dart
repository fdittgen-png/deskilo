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
  // The sectioned settings list (#188) pushes this last admin entry below
  // the 800×600 fold; scrollUntilVisible stops once the tile is BUILT
  // (cache extent), ensureVisible finishes the job.
  await tester.scrollUntilVisible(
    find.text('Workspace ID & QR'),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Workspace ID & QR'));
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

  testWidgets('the member QR URL carries the user role', (tester) async {
    await pumpWorkspaceCode(tester);

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.semanticsLabel, 'deskilo://join?role=user&code=GOODCODE22');
  });

  testWidgets('owner switches to the admin invite — its own code, role in '
      'the QR URL, no ID editing', (tester) async {
    await pumpWorkspaceCode(tester);

    await tester.tap(find.text('Admin invite'));
    await tester.pumpAndSettle();

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.semanticsLabel, 'deskilo://join?role=admin&code=ADMINCODE33');
    expect(find.text('ADMINCODE33'), findsOneWidget);
    expect(find.text('Change workspace ID'), findsNothing);
  });

  testWidgets('no owner invite exists — only member and admin segments',
      (tester) async {
    await pumpWorkspaceCode(tester);

    expect(find.text('Member invite'), findsOneWidget);
    expect(find.text('Admin invite'), findsOneWidget);
    expect(find.text('Owner invite'), findsNothing);
  });

  testWidgets('owner sets a new alphanumeric ID', (tester) async {
    final workspace = await pumpWorkspaceCode(tester);

    // The role segments (#0030) push this button below the test fold.
    await tester.ensureVisible(find.text('Change workspace ID'));
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

    await tester.ensureVisible(find.text('Change workspace ID'));
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
