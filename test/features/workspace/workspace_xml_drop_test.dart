// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3818 — a workspace file dropped on the restore tool takes the SAME path
// as a picked one: the preview and the destructive confirmation come first,
// and nothing is restored until the owner accepts. A file of another kind
// is refused in words.
import 'dart:convert';

import 'package:deskilo/core/files/file_drop_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_drop.dart';
import '../../helpers/mock_providers.dart';
import 'workspace_xml_import_screen_test.dart';

void main() {
  late RecordingImportRepository importRepository;
  late FakeFileDrop drop;

  setUp(() {
    importRepository = RecordingImportRepository();
    drop = FakeFileDrop();
  });

  Future<void> pump(WidgetTester tester) => pumpWorkspaceSettings(
    tester,
    // The picker is never asked: a drop brings its own file.
    picker: (group) async => fail('the picker must not open for a drop'),
    importRepository: importRepository,
    workspaceRepository: FakeWorkspaceRepository.withWorkspace(),
    floorPlan: CountingFloorPlanRepository()..seedSmallPlan(),
    extraOverrides: drop.overrides(),
  );

  testWidgets('a dropped file opens the confirmation and restores nothing '
      'until it is accepted', (tester) async {
    await pump(tester);
    drop.drop(
      DroppedItems([
        FakeDroppedFile('space.xml', bytes: utf8.encode(importableXml())),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Replace floor plan?'), findsOneWidget);
    expect(importRepository.calls, isEmpty);

    await confirmImport(tester);
    expect(importRepository.calls, hasLength(1));
  });

  testWidgets('cancelling the confirmation after a drop restores nothing', (
    tester,
  ) async {
    await pump(tester);
    drop.drop(
      DroppedItems([
        FakeDroppedFile('space.xml', bytes: utf8.encode(importableXml())),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspaceXmlImportCancel')));
    await tester.pumpAndSettle();
    expect(importRepository.calls, isEmpty);
  });

  testWidgets('a file of another kind is refused, no confirmation', (
    tester,
  ) async {
    await pump(tester);
    drop.drop(DroppedItems([FakeDroppedFile('space.png')]));
    await tester.pumpAndSettle();
    expect(find.textContaining('takes .xml'), findsOneWidget);
    expect(find.text('Replace floor plan?'), findsNothing);
    expect(importRepository.calls, isEmpty);
  });
}
