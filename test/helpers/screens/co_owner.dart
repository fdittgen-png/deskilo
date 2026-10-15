// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in co_owner_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mock_providers.dart';
import '../settings_sections.dart';

/// Seeds Ana BEFORE the pump (the member providers cache their first
/// fetch), then walks Settings → Members & plans.
Future<FakeWorkspaceRepository> pumpMembersWithAna(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
  CoOwnerStatus anaCoOwner = CoOwnerStatus.none,
}) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace =
      FakeWorkspaceRepository.withWorkspace(
          // #825 — these tests drive the legacy sheet; the page has its own.
          featureFlags: {'memberPage': false, ...featureFlags},
        )
        ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
        ..otherMembers.add(
          Member(
            id: 'member-2',
            workspaceId: 'ws-1',
            userId: 'user-2',
            isAdmin: false,
            isOwner: false,
            coOwner: anaCoOwner,
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
  await showWorkspaceSettings(tester);
  await tester.tap(find.text('Members & plans'));
  await tester.pumpAndSettle();
  return workspace;
}
