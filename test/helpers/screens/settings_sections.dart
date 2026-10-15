// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in settings_sections_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mock_providers.dart';
import '../settings_sections.dart';

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
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags)
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
      overrides: [...standardTestOverrides(workspace: workspace)],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  if (manage) await showWorkspaceSettings(tester);
}
