// SPDX-License-Identifier: 0BSD
//
// New-member validation (0052): a join lands PENDING — the member waits
// on the approval screen (workspace name only) until owner/admins
// confirm through the members sheet or the events quorum; single-use
// invitation codes are refused on a second redeem (0051).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/presentation/screens/pending_approval_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  testWidgets(
      'a join lands pending: the waiting screen locks the app, showing '
      'the workspace name and a re-check button', (tester) async {
    final workspace = FakeWorkspaceRepository()..joinsArePending = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Fresh user: onboarding → join.
    await tester.tap(find.text('Join a workspace'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'GOODCODE22');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(find.byType(PendingApprovalScreen), findsOneWidget);
    expect(find.text('Joined Space'), findsWidgets);
    expect(find.byKey(const ValueKey('pending-refresh')), findsOneWidget);
    // Locked: no shell around the waiting room.
    expect(find.byType(ShellBottomBar), findsNothing);

    // Once the membership is approved, re-checking releases the lock.
    workspace.myMember =
        workspace.myMember.copyWith(status: MemberStatus.active);
    await tester.tap(find.byKey(const ValueKey('pending-refresh')));
    await tester.pumpAndSettle();
    expect(find.byType(PendingApprovalScreen), findsNothing);
    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets(
      'a single-use invitation code is refused on the second redeem '
      '(0051)', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    final code = await workspace.createInvitation('ws-1', isAdmin: false);

    await workspace.joinWorkspace(code);
    expect(
      () => workspace.joinWorkspace(code),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets(
      'the members sheet approves a pending member through the RPC; '
      'reject exits them', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Nova'}
      ..otherMembers.add(
        const Member(
          id: 'member-2',
          workspaceId: 'ws-1',
          userId: 'user-2',
          isAdmin: false,
          isOwner: false,
          status: MemberStatus.pending,
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

    // The row marks the pending state.
    expect(find.text('Pending'), findsOneWidget);

    await tester.tap(find.text('Nova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve membership'));
    await tester.pumpAndSettle();

    expect(workspace.joinDecisions['member-2'], isTrue);
    expect(
      workspace.otherMembers.single.status,
      MemberStatus.active,
    );
  });

  testWidgets('the validation rules screen lists the New member domain',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Validation rules'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Validation rules'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Validation rules'));
    await tester.pumpAndSettle();

    expect(find.text('New member'), findsOneWidget);
  });
}
