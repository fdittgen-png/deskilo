// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in members_screen_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/presentation/screens/members_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_money_repository.dart';
import '../mock_providers.dart';
import '../settings_sections.dart';

Future<FakeWorkspaceRepository> pumpMembers(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FileSaver? saver,
  FakeNfcUidReader? nfc,
  Map<String, dynamic> featureFlags = const {},
  Size size = const Size(800, 2200),
}) async {
  // The settings list grew (Help + Linked accounts, 0051): keep the
  // Members & plans entry on-stage in the lazy list.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace =
      FakeWorkspaceRepository.withWorkspace(
          // #825 — these tests drive the legacy sheet; the page has its own.
          featureFlags: {'memberPage': false, ...featureFlags},
        )
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
        ...standardTestOverrides(workspace: workspace, money: money, nfc: nfc),
        if (saver != null) fileSaverProvider.overrideWithValue(saver),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await showWorkspaceSettings(tester);
  await tester.ensureVisible(find.text('Members & plans'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Members & plans'));
  await tester.pumpAndSettle();
  expect(find.byType(MembersScreen), findsOneWidget);
  return workspace;
}

/// Opens [name]'s management sheet (the row tap).
Future<void> openSheet(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.text(name));
  await tester.pumpAndSettle();
  expect(find.text(name).hitTestable(), findsOneWidget);
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}
