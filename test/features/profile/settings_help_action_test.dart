// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3068 — Help is reachable from the header of Settings, not only from the
// row at the very bottom of a long list; the row keeps its place.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('the header of Settings opens the guide; the bottom row stays',
      (tester) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final launched = <Uri>[];
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
        overrides: [
          ...standardTestOverrides(workspace: workspace),
          linkLauncherProvider.overrideWithValue((uri) async {
            launched.add(uri);
            return true;
          }),
        ],
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final action = find.descendant(
      of: find.byType(AppBar),
      matching: find.byKey(const ValueKey('settings-help-action')),
    );
    expect(action, findsOneWidget);
    expect(find.byKey(const ValueKey('settings-help')), findsOneWidget);

    await tester.tap(action);
    await tester.pump();
    expect(launched, hasLength(1));
  });
}
