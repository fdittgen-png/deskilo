// SPDX-License-Identifier: 0BSD
//
// #937 — the platform owner's overview on the Profiles list: every
// workspace they are NOT in, greyed out, and its owners on tap.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/workspace_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpProfiles(
  WidgetTester tester, {
  required bool platformOwner,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..platformOwner = platformOwner
    ..allWorkspaces.addAll(const [
      WorkspaceOverview(id: 'ws-1', name: 'Test Space', isMember: true),
      WorkspaceOverview(
        id: 'ws-9',
        name: 'Foreign Hub',
        environment: 'prod',
        memberCount: 4,
        ownerCount: 1,
      ),
    ])
    ..ownersByWorkspace['ws-9'] = const [
      WorkspaceOwner(memberId: 'o-1', name: 'Mathieu', email: 'm@x.fr'),
    ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: workspace,
        activeWorkspace: InMemoryActiveWorkspaceStore(),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Profiles'));
  await tester.pumpAndSettle();
  return workspace;
}

final _section = find.byKey(const ValueKey('profiles-platform-section'));
final _foreign = find.byKey(const ValueKey('platform-workspace-ws-9'));

void main() {
  testWidgets('nothing changes for anyone who is not the platform owner',
      (tester) async {
    await pumpProfiles(tester, platformOwner: false);
    expect(_section, findsNothing);
    expect(_foreign, findsNothing);
  });

  testWidgets('every other workspace is listed greyed out; one\'s own is not '
      'duplicated', (tester) async {
    await pumpProfiles(tester, platformOwner: true);
    expect(_section, findsOneWidget);
    expect(_foreign, findsOneWidget);
    expect(find.byKey(const ValueKey('platform-workspace-ws-1')), findsNothing,
        reason: 'a workspace one is a member of is already in the list above');
    expect(find.text('Foreign Hub'), findsOneWidget);
    expect(find.textContaining('4 members'), findsOneWidget);
  });

  testWidgets('tapping a greyed-out workspace names its owners with their '
      'e-mail, and the read is logged', (tester) async {
    final workspace = await pumpProfiles(tester, platformOwner: true);
    await tester.tap(_foreign);
    await tester.pumpAndSettle();
    expect(find.text('Owners of Foreign Hub'), findsOneWidget);
    expect(find.text('Mathieu'), findsOneWidget);
    expect(find.text('m@x.fr'), findsOneWidget);
    expect(workspace.ownerReads, ['ws-9']);
  });
}
