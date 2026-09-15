// SPDX-License-Identifier: 0BSD
//
// The Excel export surface (#395): the tile exists only while the
// dataExport feature is on (its ONLY surface, so the flag gate is the
// tile), and tapping it hands the saver a real workbook — proven by
// unzipping what was saved, the same bar a spreadsheet reader applies.

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

/// #1310 S0 — an ADMIN whose role row does not carry exportData. An owner
/// holds every permission by construction, so the permission can only be
/// narrowed on somebody who is not one.
FakeWorkspaceRepository _adminWithout(String permission) {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.myMember = workspace.myMember.copyWith(isOwner: false);
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(rolePermissions: {
    'admin': [
      for (final p in defaultPermissionsFor(PermissionRole.admin))
        if (p.wireName != permission) p.wireName,
      // Reaching Workspace settings at all: the admin default row does
      // not carry it, and this test is about exportData, not about who
      // may open the screen.
      WorkspacePermission.workspaceSettings.wireName,
    ],
  });
  return workspace;
}

Future<List<({String name, Uint8List bytes})>> _pump(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
  FakeWorkspaceRepository? workspace,
}) async {
  tester.view.physicalSize = const Size(800, 4600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final saved = <({String name, Uint8List bytes})>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: workspace ??
              FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags),
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
        ),
        fileSaverProvider.overrideWithValue(
          ({required bytes, required fileName}) async {
            saved.add((name: fileName, bytes: bytes));
            return '/local/$fileName';
          },
        ),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Workspace'));
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  testWidgets('with dataExport OFF the tile does not exist — a feature '
      'off means none of its surfaces remain', (tester) async {
    await _pump(tester, featureFlags: {'dataExport': false});
    expect(
      find.byKey(const Key('workspaceSettingsExportExcel')),
      findsNothing,
    );
  });

  testWidgets('the tile saves a real workbook: eleven tabs, named with '
      'the workspace code and the pinned date', (tester) async {
    final saved = await _pump(tester);

    final tile = find.byKey(const Key('workspaceSettingsExportExcel'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    final file = saved.single;
    expect(file.name, 'deskilo-export-GOODCODE22-2026-05-13.xlsx');
    // PK magic + all eleven worksheets present in the archive.
    expect(file.bytes.sublist(0, 2), [0x50, 0x4B]);
    final archive = ZipDecoder().decodeBytes(file.bytes);
    for (var i = 1; i <= 11; i++) {
      expect(archive.findFile('xl/worksheets/sheet$i.xml'), isNotNull,
          reason: 'sheet$i missing — a dataset dropped out of the export');
    }
    expect(find.textContaining('/local/deskilo-export'), findsOneWidget);
  });

  testWidgets('#1310 S0 — without the data-export permission the tile is '
      'gone: exportData is what governs BULK export', (tester) async {
    await _pump(tester, workspace: _adminWithout('exportData'));
    expect(find.byKey(const Key('workspaceSettingsExportExcel')), findsNothing);
  });

  testWidgets('#1310 S0 — an admin who keeps the permission still has it',
      (tester) async {
    await _pump(tester, workspace: _adminWithout('manageIntegrations'));
    expect(
      find.byKey(const Key('workspaceSettingsExportExcel')),
      findsOneWidget,
      reason: 'narrowing another permission must not take the export away',
    );
  });
}
