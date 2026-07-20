// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpMembers(
  WidgetTester tester, {
  FakeMoneyRepository? money,
}) async {
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
      overrides: standardTestOverrides(workspace: workspace, money: money),
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

  testWidgets('the owner records a service onto another member\'s bill (#129)',
      (tester) async {
    final money = FakeMoneyRepository();
    await pumpMembers(tester, money: money);

    // Ana's row is the second one.
    await tester.tap(find.byIcon(Icons.room_service_outlined).last);
    await tester.pumpAndSettle();

    expect(find.text('Add service for Ana'), findsOneWidget);
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    final recorded = money.recordedServiceCharges.single;
    expect(recorded.workspaceId, 'ws-1');
    expect(recorded.subjectMemberId, 'member-2');
    expect(recorded.serviceId, 'service-coffee');
    expect(recorded.quantity, 1);
  });

  testWidgets('the owner switches a member to pay-as-you-go overage (0041)',
      (tester) async {
    final workspace = await pumpMembers(tester);

    // Members default to the blocked policy.
    expect(workspace.otherMembers.single.overagePolicy, OveragePolicy.blocked);

    // Ana's row is the second one.
    await tester.tap(find.byTooltip('Over-consumption').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Charge overage (pay-as-you-go)'));
    await tester.pumpAndSettle();

    expect(workspace.otherMembers.single.overagePolicy, OveragePolicy.payg);
  });

  testWidgets('the owner flags a member as a kiosk device (0043): row shows '
      'Kiosk, billing controls disappear', (tester) async {
    final workspace = await pumpMembers(tester);

    // Ana's row: flag her account as the wall tablet.
    await tester.tap(find.byTooltip('Make kiosk device').last);
    await tester.pumpAndSettle();

    expect(workspace.otherMembers.single.isKiosk, isTrue);
    expect(find.text('Kiosk'), findsOneWidget);
    // A kiosk is a device: no subscription, no over-consumption, no role
    // toggle, no badges of its own — only the revert control remains.
    expect(find.byIcon(Icons.percent), findsOneWidget); // owner's row only
    expect(find.byTooltip('Revert kiosk to member'), findsOneWidget);

    await tester.tap(find.byTooltip('Revert kiosk to member'));
    await tester.pumpAndSettle();
    expect(workspace.otherMembers.single.isKiosk, isFalse);
  });

  testWidgets('issuing a badge (0043) shows the one-time QR and lists it; '
      'revoking marks it', (tester) async {
    final workspace = await pumpMembers(tester);

    await tester.tap(find.byTooltip('Badges').last);
    await tester.pumpAndSettle();
    expect(find.text('No badges yet.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('badge-issue-button')));
    await tester.pumpAndSettle();

    // The raw token renders exactly once as a QR.
    expect(find.byKey(const ValueKey('badge-qr')), findsOneWidget);
    expect(find.textContaining('shown only once'), findsOneWidget);
    expect(workspace.badges.single.memberId, 'member-2');
    expect(workspace.badges.single.isActive, isTrue);

    // Reopen: the badge lists with a revoke action; revoking flags it.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Badges').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();

    expect(workspace.badges.single.isActive, isFalse);
    expect(find.text('Revoked'), findsOneWidget);
  });

  testWidgets('long-press pauses an active membership', (tester) async {
    final workspace = await pumpMembers(tester);

    await tester.longPress(find.text('Ana'));
    await tester.pumpAndSettle();

    expect(workspace.otherMembers.single.status, MemberStatus.paused);
  });

  testWidgets('invite button leads to the workspace ID & QR screen (#195)',
      (tester) async {
    await pumpMembers(tester);

    expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Workspace ID & QR'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('GOODCODE22'), findsOneWidget);
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

  testWidgets('the owner promotes a regular member — routed through '
      'validation, not applied immediately (0035)', (tester) async {
    final workspace = await pumpMembers(tester);

    // Ana (member-2) is a regular member: her row offers "Make admin".
    await tester.tap(find.byTooltip('Make admin'));
    await tester.pumpAndSettle();

    expect(workspace.lastRoleChange, ('ws-1', 'member-2', true));
    expect(
      find.text('Role change sent for validation.'),
      findsOneWidget,
    );
  });

  testWidgets('an admin can be demoted; the owner has no role toggle',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
      ..otherMembers.add(
        const Member(
          id: 'member-2',
          workspaceId: 'ws-1',
          userId: 'user-2',
          isAdmin: true,
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

    // The admin offers demotion; the owner (Flo) offers no role toggle.
    expect(find.byTooltip('Make regular member'), findsOneWidget);
    expect(find.byTooltip('Make admin'), findsNothing);

    await tester.tap(find.byTooltip('Make regular member'));
    await tester.pumpAndSettle();
    expect(workspace.lastRoleChange, ('ws-1', 'member-2', false));
  });

}
