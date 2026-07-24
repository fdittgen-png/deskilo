// SPDX-License-Identifier: 0BSD
//
// Self-service badges (0053): a member mints their OWN printable QR
// badge and registers their OWN RFID/NFC card from Settings → My badge —
// the same BadgeManagerDialog the admins use, with the self RPCs.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> openMyBadge(
  WidgetTester tester, {
  FakeNfcUidReader? nfc,
  bool plainMember = false,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace();
  if (plainMember) {
    workspace.myMember =
        workspace.myMember.copyWith(isAdmin: false, isOwner: false);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace, nfc: nfc),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('settings-my-badge')));
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets(
      'Settings → My badge mints my own QR (shown once, printable as '
      'PDF) — no admin involved', (tester) async {
    final workspace = await openMyBadge(tester);

    await tester.tap(find.byKey(const ValueKey('badge-issue-button')));
    await tester.pumpAndSettle();

    // The one-time QR renders with the Save-as-PDF affordance.
    expect(find.byKey(const ValueKey('badge-qr')), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-save-pdf')), findsOneWidget);
    // Minted onto MY membership.
    expect(workspace.badges.single.memberId, 'member-1');
  });

  testWidgets(
      'the badge manager names its WORKSPACE — badges are per workspace '
      '(0056), so the wrong active profile is visible before registering',
      (tester) async {
    await openMyBadge(tester);

    final line = find.byKey(const ValueKey('badge-workspace-name'));
    expect(line, findsOneWidget);
    expect(tester.widget<Text>(line).data, 'Test Space');
  });

  testWidgets(
      'with NFC available, "Register card" reads my tap and registers '
      'the card on my membership', (tester) async {
    final nfc = FakeNfcUidReader(available: true);
    final workspace = await openMyBadge(tester, nfc: nfc);

    await tester
        .tap(find.byKey(const ValueKey('badge-register-nfc-button')));
    await tester.pumpAndSettle();
    nfc.tap('04a1b2c3d4');
    await tester.pumpAndSettle();

    final badge = workspace.badges.single;
    expect(badge.kind, BadgeKind.nfc);
    expect(badge.memberId, 'member-1');
    expect(badge.label, 'uid:04a1b2c3d4');
  });

  testWidgets(
      'My badge is NOT role-gated: a PLAIN member (no admin, no owner) '
      'sees the tile and can mint a badge (field report pin)',
      (tester) async {
    final workspace = await openMyBadge(tester, plainMember: true);

    await tester.tap(find.byKey(const ValueKey('badge-issue-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('badge-qr')), findsOneWidget);
    expect(workspace.badges.single.memberId, 'member-1');
  });

  testWidgets(
      'a REVOKED badge is deleted for good by swiping it to the right; '
      'live badges cannot be swiped', (tester) async {
    final workspace = await openMyBadge(tester, plainMember: true);
    // Seed one revoked and one live badge of mine.
    final first = await workspace.issueMyBadge('ws-1');
    await workspace.revokeMyBadge(first.badgeId);
    await workspace.issueMyBadge('ws-1');
    // Re-open so the list loads the seeded badges.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-my-badge')));
    await tester.pumpAndSettle();

    // The revoked row swipes right and disappears — deleted server-side.
    final dismissible = find.byKey(ValueKey('badge-dismiss-${first.badgeId}'));
    expect(dismissible, findsOneWidget);
    await tester.drag(dismissible, const Offset(320, 0));
    await tester.pumpAndSettle();

    expect(find.text('Revoked'), findsNothing);
    expect(workspace.badges.single.isActive, isTrue);
    // The live badge has no swipe affordance.
    expect(
      find.byKey(ValueKey('badge-dismiss-${workspace.badges.single.id}')),
      findsNothing,
    );
  });

  testWidgets('I can revoke my own badge from the list', (tester) async {
    final workspace = await openMyBadge(tester);
    // Seed one existing badge of mine.
    await workspace.issueMyBadge('ws-1');
    // Re-open so the list loads the seeded badge.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-my-badge')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();

    expect(workspace.badges.single.isActive, isFalse);
  });
}
