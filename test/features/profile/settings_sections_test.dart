// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Structural test for the sectioned settings list (#188, regrouped by
// ownership in #1307): Profiles on top, then My account, My membership,
// This workspace, Administration, Governance, Advanced and Help & about,
// with Sign out closing the list. A plain member meets none of the three
// workspace sections — and always keeps the four essentials: Sign out,
// Language, the privacy policy and Help.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/settings_sections.dart';

Future<void> pumpSettingsAs(
  WidgetTester tester, {
  required bool isAdmin,
  required bool isOwner,
  Map<String, dynamic> featureFlags = const {},
  bool manage = false,
  Size size = const Size(800, 3600),
}) async {
  // The sectioned list no longer fits the default 800×600 lazy-list
  // viewport; a taller view keeps every tile and header built.
  // 1600→1700 (#478): the Billing & reports admin entry added a row.
  // 1700→1800 (#486): the Payment instructions admin entry added one.
  // 1800→1900 (#513): the Role management admin entry added one.
  // 1900→2000 (#552): the owner WhatsApp-channel tile added one.
  // 2000→2700 (#560): the About section (7 tiles + support block).
  // #711 added the Region & formats tile; 2700 no longer reached Sign out.
  // 3300→3600 (#1307): section headers for My account, My membership,
  // This workspace and Governance.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: featureFlags,
  )..myMember = Member(
      id: 'member-1',
      workspaceId: 'ws-1',
      userId: 'user-1',
      isAdmin: isAdmin,
      isOwner: isOwner,
      status: MemberStatus.active,
    );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  if (manage) await showWorkspaceSettings(tester);
}

double dy(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('personal settings and workspace configuration have distinct scopes', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpSettingsAs(tester, isAdmin: true, isOwner: true, size: const Size(320, 1100));
    expect(find.byKey(const ValueKey('settings-personal-tab')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-workspace-tab')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Status'), 160, scrollable: find.descendant(of: find.byKey(const PageStorageKey('settings-personal')), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Workspace'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-workspace-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Status'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-personal-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal sections stay separate from workspace task groups', (tester) async {
    await pumpSettingsAs(tester, isAdmin: true, isOwner: true);
    for (final header in ['Back to Me', 'My account', 'My membership', 'Advanced', 'Help & about', 'Sign out']) {
      expect(find.text(header), findsOneWidget);
    }
    expect(find.text('Workspace'), findsNothing);
    expect(dy(tester, 'My account'), lessThan(dy(tester, 'My account is in Me')));
    expect(dy(tester, 'My membership'), lessThan(dy(tester, 'Status')));
    await openSettingsSection(tester, 'advanced');
    expect(find.text('Developer mode'), findsOneWidget);
    await showWorkspaceSettings(tester);
    expect(find.text('Status'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
    expect(dy(tester, 'This workspace'), lessThan(dy(tester, 'Workspace')));
    expect(dy(tester, 'Features'), lessThan(dy(tester, 'Administration')));
    expect(dy(tester, 'Administration'), lessThan(dy(tester, 'Members & plans')));
    expect(dy(tester, 'Governance'), lessThan(dy(tester, 'Roles')));
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets(
      'a plain member sees none of the workspace sections, and keeps the '
      'four essentials', (tester) async {
    await pumpSettingsAs(tester, isAdmin: false, isOwner: false);

    for (final header in ['This workspace', 'Administration', 'Governance']) {
      expect(find.text(header), findsNothing, reason: '"$header" leaked');
    }
    for (final entry in [
      'Workspace',
      'Members & plans',
      'Availability',
      'Services',
      'Accessories',
      'Billing',
      'Features',
      'Validation rules',
      'Workspace ID & QR',
      'Roles',
    ]) {
      expect(find.text(entry), findsNothing, reason: '"$entry" leaked');
    }
    // #1306/#1307 — Members is a bottom-bar destination; Settings is not a
    // second door to it.
    expect(find.text('Members'), findsNothing);
    // The member's own sections stay.
    for (final header in ['Back to Me', 'My account', 'My membership', 'Help & about']) {
      expect(find.text(header), findsOneWidget, reason: 'missing "$header"');
    }
    // The four essentials, pinned by what they are.
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('My account is in Me'), findsOneWidget); // #1823
    expect(find.byKey(const ValueKey('about-privacy')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-help')), findsOneWidget);
  });

  testWidgets(
      '#1307 — a delegate holding one permission finds its entry and nothing '
      'else of the workspace', (tester) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember = const Member(
      id: 'member-1',
      workspaceId: 'ws-1',
      userId: 'user-1',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    );
    workspace.workspaces[0] = workspace.workspaces[0].copyWith(
      rolePermissions: {
        'member': ['manageBilling'],
      },
    );
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await showWorkspaceSettings(tester);
    expect(find.text('This workspace'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Roles'), findsNothing,
        reason: 'the matrix is for whoever holds manageRoles');
    for (final entry in ['Workspace', 'Availability', 'Features', 'Members & plans']) {
      expect(find.text(entry), findsNothing, reason: '"$entry" leaked');
    }
    expect(find.text('Administration'), findsNothing);
  });

  // Feature-gating of the admin entries (#146 rule): a feature's config entry
  // appears only while the feature is on. onlinePayments and
  // accessorySupplements are default-off; nfcBadges is default-on.
  testWidgets(
      'an owner with the features OFF sees no payments, NFC or accessories '
      'entry', (tester) async {
    await pumpSettingsAs(
      tester,
      isAdmin: true,
      isOwner: true,
      manage: true,
      featureFlags: const {
        'onlinePayments': false,
        'nfcBadges': false,
        'accessorySupplements': false,
        'services': false,
      },
    );

    for (final entry in [
      'Online payments',
      'RFID / NFC badges',
      'Accessories',
      'Services',
    ]) {
      expect(find.text(entry), findsNothing, reason: '"$entry" leaked when off');
    }
    // The master Features toggle is always reachable to switch them back on.
    expect(find.text('Features'), findsOneWidget);
  });

  testWidgets(
      'an owner with the features ON sees payments, NFC, accessories and '
      'services entries', (tester) async {
    await pumpSettingsAs(
      tester,
      isAdmin: true,
      isOwner: true,
      manage: true,
      featureFlags: const {
        'onlinePayments': true,
        'nfcBadges': true,
        'accessorySupplements': true,
        'services': true,
      },
    );

    for (final entry in [
      'Online payments',
      'RFID / NFC badges',
      'Accessories',
      'Services',
    ]) {
      expect(find.text(entry), findsOneWidget, reason: '"$entry" missing when on');
    }
  });
}
