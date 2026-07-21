// SPDX-License-Identifier: MIT
//
// Members & plans. Since the UX pass, every per-member action lives in
// the row's MANAGEMENT SHEET (tap the row → labeled tiles) instead of a
// pile of icon buttons — tests open the sheet first.
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:deskilo/features/workspace/domain/member_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpMembers(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FileSaver? saver,
  FakeNfcUidReader? nfc,
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
      overrides: [
        ...standardTestOverrides(
          workspace: workspace,
          money: money,
          nfc: nfc,
        ),
        if (saver != null) fileSaverProvider.overrideWithValue(saver),
      ],
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

/// Opens [name]'s management sheet (the row tap).
Future<void> openSheet(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
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

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Subscription'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50%').last);
    await tester.pumpAndSettle();

    expect(workspace.otherMembers.single.subscriptionPct, 50);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('the owner can assign a negotiated custom percentage',
      (tester) async {
    final workspace = await pumpMembers(tester);

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Subscription'));
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

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Add service for Ana'));
    await tester.pumpAndSettle();
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

    expect(workspace.otherMembers.single.overagePolicy, OveragePolicy.blocked);

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('When days run out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Charge overage (pay-as-you-go)'));
    await tester.pumpAndSettle();

    expect(workspace.otherMembers.single.overagePolicy, OveragePolicy.payg);
  });

  testWidgets('the owner flags a member as a kiosk device (0043): row shows '
      'Kiosk, billing actions disappear from the sheet', (tester) async {
    final workspace = await pumpMembers(tester);

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Make kiosk device'));
    await tester.pumpAndSettle();

    expect(workspace.otherMembers.single.isKiosk, isTrue);
    expect(find.text('Kiosk'), findsOneWidget);

    // A kiosk is a device: its sheet offers no billing/role knobs — only
    // the revert (and pause) controls remain.
    await openSheet(tester, 'Ana');
    expect(find.text('Subscription'), findsNothing);
    expect(find.text('When days run out'), findsNothing);
    expect(find.text('Reservation limit'), findsNothing);
    expect(find.text('Badges'), findsNothing);

    await tester.tap(find.text('Revert kiosk to member'));
    await tester.pumpAndSettle();
    expect(workspace.otherMembers.single.isKiosk, isFalse);
  });

  testWidgets('issuing a badge (0043) shows the one-time QR and lists it; '
      'revoking marks it', (tester) async {
    final workspace = await pumpMembers(tester);

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Badges'));
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
    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Badges'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();

    expect(workspace.badges.single.isActive, isFalse);
    expect(find.text('Revoked'), findsOneWidget);
  });

  testWidgets('the one-time badge QR downloads as a printable PDF card '
      '(UX pass)', (tester) async {
    final saved = <(String, Uint8List)>[];
    await pumpMembers(
      tester,
      saver: ({required bytes, required fileName}) async {
        saved.add((fileName, bytes));
        return '/tmp/$fileName';
      },
    );

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Badges'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('badge-issue-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('badge-save-pdf')));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.$1, 'deskilo-badge-ana.pdf');
    // A real PDF, saved locally.
    expect(String.fromCharCodes(saved.single.$2.sublist(0, 5)), '%PDF-');
    expect(find.textContaining('Saved to'), findsOneWidget);
  });

  testWidgets('registering an RFID/NFC card (0046): the tap prompt reads a '
      'UID and the badge lists as an NFC credential', (tester) async {
    final nfc = FakeNfcUidReader(available: true);
    final workspace = await pumpMembers(tester, nfc: nfc);

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Badges'));
    await tester.pumpAndSettle();

    // NFC available → the register-card action shows next to New badge.
    await tester.tap(find.byKey(const ValueKey('badge-register-nfc-button')));
    await tester.pumpAndSettle();
    expect(find.text('Register a card'), findsOneWidget);

    // A physical tap delivers the tag UID (already normalized).
    nfc.tap('04a2b3c4d5');
    await tester.pumpAndSettle();

    expect(find.text('Card registered.'), findsOneWidget);
    final badge = workspace.badges.single;
    expect(badge.memberId, 'member-2');
    expect(badge.kind, BadgeKind.nfc);
    expect(badge.label, 'uid:04a2b3c4d5');
  });

  testWidgets('a second tap of the same card is refused (0046 dup guard)',
      (tester) async {
    final nfc = FakeNfcUidReader(available: true);
    final workspace = await pumpMembers(tester, nfc: nfc);
    workspace.badges.add(
      MemberBadge(
        id: 'badge-existing',
        workspaceId: 'ws-1',
        memberId: 'member-2',
        label: 'uid:04a2b3c4d5',
        createdAt: DateTime.now(),
        kind: BadgeKind.nfc,
      ),
    );

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Badges'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('badge-register-nfc-button')));
    await tester.pumpAndSettle();
    nfc.tap('04a2b3c4d5');
    await tester.pumpAndSettle();

    expect(find.text('That card is already registered.'), findsOneWidget);
    expect(workspace.badges.where((b) => b.isActive), hasLength(1));
  });

  testWidgets('no NFC hardware hides the register-card action (0046)',
      (tester) async {
    // Default fake reader reports NFC unavailable.
    await pumpMembers(tester);

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Badges'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('badge-register-nfc-button')),
      findsNothing,
    );
    // The QR path stays available everywhere.
    expect(find.byKey(const ValueKey('badge-issue-button')), findsOneWidget);
  });

  testWidgets("the owner caps another member's simultaneous reservations "
      '(0044): preset persists, chip shows on the row', (tester) async {
    final workspace = await pumpMembers(tester);

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Reservation limit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(workspace.otherMembers.single.maxActiveReservations, 3);
    expect(find.text('max 3'), findsOneWidget);

    // "No limit" lifts the cap again.
    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Reservation limit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No limit'));
    await tester.pumpAndSettle();
    expect(workspace.otherMembers.single.maxActiveReservations, isNull);
  });

  testWidgets('the own sheet never offers the reservation limit '
      '(0044: not for themselves)', (tester) async {
    await pumpMembers(tester);

    await openSheet(tester, 'Flo');
    expect(find.text('Reservation limit'), findsNothing);
    // …while other self-service-safe actions are present.
    expect(find.text('Subscription'), findsOneWidget);
  });

  testWidgets('an admin reaches Members & plans but sees no owner-only '
      'actions (0044 widened access)', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
      ..myMember = const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: true,
        isOwner: false,
        status: MemberStatus.active,
      )
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

    // Ana's sheet for an ADMIN: limit + badges, none of the owner knobs.
    await openSheet(tester, 'Ana');
    expect(find.text('Reservation limit'), findsOneWidget);
    expect(find.text('Badges'), findsOneWidget);
    expect(find.text('Subscription'), findsNothing);
    expect(find.text('Make admin'), findsNothing);
    expect(find.text('Make kiosk device'), findsNothing);
    expect(find.text('When days run out'), findsNothing);
    expect(find.text('Pause membership'), findsNothing);

    await tester.tap(find.text('Reservation limit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(workspace.otherMembers.single.maxActiveReservations, 5);
  });

  testWidgets('pausing is a visible sheet action now (was a hidden '
      'long-press)', (tester) async {
    final workspace = await pumpMembers(tester);

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Pause membership'));
    await tester.pumpAndSettle();
    expect(workspace.otherMembers.single.status, MemberStatus.paused);

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Reactivate membership'));
    await tester.pumpAndSettle();
    expect(workspace.otherMembers.single.status, MemberStatus.active);
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

    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Make admin'));
    await tester.pumpAndSettle();

    expect(workspace.lastRoleChange, ('ws-1', 'member-2', true));
    expect(
      find.text('Role change sent for validation.'),
      findsOneWidget,
    );
  });

  testWidgets('an admin can be demoted; the owner sheet has no role toggle',
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

    // The owner's OWN sheet offers no role toggle…
    await openSheet(tester, 'Flo');
    expect(find.text('Make admin'), findsNothing);
    expect(find.text('Make regular member'), findsNothing);
    await tester.tapAt(const Offset(10, 10)); // dismiss
    await tester.pumpAndSettle();

    // …the admin's sheet offers demotion.
    await openSheet(tester, 'Ana');
    await tester.tap(find.text('Make regular member'));
    await tester.pumpAndSettle();
    expect(workspace.lastRoleChange, ('ws-1', 'member-2', false));
  });
}
