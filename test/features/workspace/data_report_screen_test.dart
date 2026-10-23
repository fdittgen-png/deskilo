// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The data report's surface (#2862): its tile sits beside the Excel export
// only while dataReport — and so the export it reads — is on, and tapping
// it hands the saver a PDF that carries the drawn plan of the level.
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/real_async.dart';
import '../../helpers/settings_sections.dart';

const _tile = Key('workspaceSettingsDataReport');

Future<List<({String name, Uint8List bytes})>> _pump(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
}) async {
  tester.view.physicalSize = const Size(800, 4600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final saved = <({String name, Uint8List bytes})>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: featureFlags,
          ),
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
        ),
        fileSaverProvider.overrideWithValue(({
          required bytes,
          required fileName,
        }) async {
          saved.add((name: fileName, bytes: bytes));
          return '/local/$fileName';
        }),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await showWorkspaceSettings(tester);
  await tester.tap(find.byKey(const ValueKey('settings-reports')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('workspace-section-documents')));
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  testWidgets('off, or with the export it reads off, the tile is gone', (
    tester,
  ) async {
    await _pump(tester, featureFlags: {'dataReport': false});
    expect(find.byKey(_tile), findsNothing);
    expect(
      find.byKey(const Key('workspaceSettingsExportExcel')),
      findsOneWidget,
    );
  });

  testWidgets('without dataExport there is no data report either', (
    tester,
  ) async {
    await _pump(tester, featureFlags: {'dataExport': false});
    expect(find.byKey(_tile), findsNothing);
  });

  testWidgets('the tile saves the report: a PDF with the plan drawn in it', (
    tester,
  ) async {
    final saved = await _pump(tester);
    final tile = find.byKey(_tile);
    await tester.ensureVisible(tile);
    await tester.runAsync(() async {
      await tester.tap(tile);
      await untilReal(() async {
        await tester.pump();
        return saved.isNotEmpty;
      }, what: 'the data report');
    });
    await tester.pumpAndSettle();

    final file = saved.single;
    expect(file.name, 'test-space-data-report.pdf');
    final raw = String.fromCharCodes(file.bytes);
    expect(raw.startsWith('%PDF-'), isTrue);
    expect(
      raw,
      matches(RegExp(r'/Subtype\s*/Image')),
      reason: 'the level plan is drawn into the report',
    );
    expect(
      find.textContaining('/local/test-space-data-report.pdf'),
      findsOneWidget,
    );
  });
}
