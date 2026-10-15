// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in workspace_settings_screen_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/workspace/presentation/screens/workspace_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_floor_plan_repository.dart';
import '../fake_money_repository.dart';
import '../mock_providers.dart';
import '../section_jump.dart';
import '../settings_sections.dart';
import '../workspace_settings_groups.dart';

Future<FakeWorkspaceRepository> pumpWorkspaceSettings(
  WidgetTester tester, {
  FileSaver? saver,
  FakeFloorPlanRepository? floorPlan,
  FakeWorkspaceRepository? repository,
  FakeMoneyRepository? money,
  bool settle = true,
  bool expand = true,
  bool reports = false,
  Size size = const Size(800, 4600),
}) async {
  // The settings form grew past the default 800px test viewport (#155,
  // three more payment fields in #192, the WhatsApp-group section in
  // #231); a taller view keeps every field + Save built without
  // scrolling.
  // 0049 added the invitation-template section — grow again.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final workspace = repository ?? FakeWorkspaceRepository.withWorkspace();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: workspace,
          floorPlan: floorPlan,
          money: money,
        ),
        if (saver != null) fileSaverProvider.overrideWithValue(saver),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await showWorkspaceSettings(tester);
  await tester.ensureVisible(find.text('Workspace'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Workspace'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // #1563 — a read still in flight leaves a spinner on screen, and a
    // spinner never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  if (reports) {
    await tapSection(tester, 'workspace-section-payments');
    await tester.pumpAndSettle();
    final reportsLink = find.descendant(
      of: find.byKey(const Key('workspaceSettingsReports')),
      matching: find.text('Reports'),
    );
    await tester.ensureVisible(reportsLink);
    await tester.pumpAndSettle();
    await tester.tap(reportsLink);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('workspace-section-documents')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-section-documents')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workspace-section-documents')).hitTestable(),
      findsOneWidget,
    );
  } else {
    expect(find.byType(WorkspaceSettingsScreen), findsOneWidget);
    if (expand) await openWorkspaceSettingsGroups(tester);
  }
  return workspace;
}
