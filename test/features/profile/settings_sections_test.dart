// SPDX-License-Identifier: 0BSD
//
// Structural test for the sectioned settings list (#188): Profiles on top,
// then the Administration / Preferences / Advanced sections in that order,
// with Sign out set apart at the bottom. A plain member must not see the
// Administration header (nor any of its entries) at all.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/trace/dev_mode.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// In-memory [DevModeStore]; settings watches it, keep it off the channels.
class _InMemoryDevModeStore implements DevModeStore {
  bool enabled = false;

  @override
  Future<bool> read() async => enabled;

  @override
  Future<void> write(bool enabled) async => this.enabled = enabled;
}

Future<void> pumpSettingsAs(
  WidgetTester tester, {
  required bool isAdmin,
  required bool isOwner,
}) async {
  // The sectioned list no longer fits the default 800×600 lazy-list
  // viewport; a taller view keeps every tile and header built.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..myMember = Member(
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
        devModeStoreProvider.overrideWithValue(_InMemoryDevModeStore()),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

double dy(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets(
      'owner sees Profiles first, then the Administration, Preferences and '
      'Advanced sections in order, with Sign out at the bottom',
      (tester) async {
    await pumpSettingsAs(tester, isAdmin: true, isOwner: true);

    for (final header in ['Administration', 'Preferences', 'Advanced']) {
      expect(find.text(header), findsOneWidget, reason: 'missing "$header"');
    }

    // Profiles is the ungrouped top entry.
    expect(dy(tester, 'Profiles'), lessThan(dy(tester, 'Administration')));
    // Administration wraps the admin entries (Workspace … Workspace ID & QR).
    expect(dy(tester, 'Administration'), lessThan(dy(tester, 'Workspace')));
    expect(
      dy(tester, 'Workspace ID & QR'),
      lessThan(dy(tester, 'Preferences')),
    );
    // Preferences wraps Language and Theme.
    expect(dy(tester, 'Preferences'), lessThan(dy(tester, 'Language')));
    expect(dy(tester, 'Theme'), lessThan(dy(tester, 'Advanced')));
    // Advanced wraps the developer entries; Sign out closes the list.
    expect(dy(tester, 'Advanced'), lessThan(dy(tester, 'Developer mode')));
    expect(dy(tester, 'Developer mode'), lessThan(dy(tester, 'Sign out')));
    // Sections are visually separated.
    expect(find.byType(Divider), findsWidgets);
  });

  testWidgets(
      'a plain member sees no Administration header and none of its entries',
      (tester) async {
    await pumpSettingsAs(tester, isAdmin: false, isOwner: false);

    expect(find.text('Administration'), findsNothing);
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
    ]) {
      expect(find.text(entry), findsNothing, reason: '"$entry" leaked');
    }
    // The personal sections stay.
    expect(find.text('Profiles'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
