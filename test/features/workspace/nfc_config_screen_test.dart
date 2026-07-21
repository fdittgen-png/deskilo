// SPDX-License-Identifier: MIT
//
// Owner RFID/NFC configuration (0046): the workspace toggle + this
// device's NFC status. Registration itself is per member (see the members
// screen tests).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpNfcConfig(
  WidgetTester tester, {
  FakeNfcUidReader? nfc,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace, nfc: nfc),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push('/nfc-config');
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets('reachable from settings and shows device status + the toggle',
      (tester) async {
    await pumpNfcConfig(tester, nfc: FakeNfcUidReader(available: true));

    expect(find.text('RFID / NFC badges'), findsWidgets);
    expect(find.byKey(const ValueKey('nfc-feature-switch')), findsOneWidget);
    expect(find.text('NFC available and enabled'), findsOneWidget);
    // Default-on feature → the switch is on.
    final sw = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('nfc-feature-switch')),
    );
    expect(sw.value, isTrue);
  });

  testWidgets('a device without NFC shows the unavailable notice',
      (tester) async {
    await pumpNfcConfig(tester); // default fake: NFC unavailable

    expect(find.textContaining('No NFC here'), findsOneWidget);
  });

  testWidgets('toggling off writes the feature flag map with nfcBadges false',
      (tester) async {
    final workspace =
        await pumpNfcConfig(tester, nfc: FakeNfcUidReader(available: true));

    await tester.tap(find.byKey(const ValueKey('nfc-feature-switch')));
    await tester.pumpAndSettle();

    final flags = workspace.workspaces.single.featureFlags;
    expect(flags['nfcBadges'], isFalse);
  });

  testWidgets('workers cannot reach the NFC config route', (tester) async {
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
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/nfc-config');
    await tester.pumpAndSettle();

    // Redirected away — the config title never appears in an app bar.
    expect(find.widgetWithText(AppBar, 'RFID / NFC badges'), findsNothing);
  });
}
