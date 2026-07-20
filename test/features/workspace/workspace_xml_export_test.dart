// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_accessory_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

Future<void> pumpWorkspaceSettings(
  WidgetTester tester, {
  required FileSaver saver,
  FakeAccessoryRepository? accessories,
}) async {
  // The settings form outgrew the 800×600 test viewport long ago (#155);
  // the export tile sits below Save, so keep the whole form built.
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final floorPlan = FakeFloorPlanRepository()..seedSmallPlan();
  // v2 (#180): the catalog (incl. an inactive entry) and the one seat's
  // assignments export too.
  final accessoryRepository = accessories ?? FakeAccessoryRepository();
  if (accessories == null) {
    accessoryRepository.seedSmallCatalog();
    accessoryRepository.seatAccessories[floorPlan.seats.single.id] = {
      accessoryRepository.accessories.first.id, // Monitor (active)
      accessoryRepository.accessories.last.id, // Docking station (inactive)
    };
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          floorPlan: floorPlan,
          accessories: accessoryRepository,
        ),
        fileSaverProvider.overrideWithValue(saver),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Workspace'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'the export tile serializes settings + floor plan and saves an .xml '
      'file locally (#164, not shared)', (tester) async {
    final saved = <(String, Uint8List)>[];
    await pumpWorkspaceSettings(
      tester,
      saver: ({required bytes, required fileName}) async {
        saved.add((fileName, bytes));
        return '/local/$fileName';
      },
    );

    final tile = find.byKey(const Key('workspaceSettingsExportXml'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.$1, 'deskilo-test-space.xml');

    // The payload round-trips through the pinned schema (#164/#180): the
    // seeded ws-1 settings + the one-level plan, no ids, no invite code.
    final xml = utf8.decode(saved.single.$2);
    expect(xml, isNot(contains('GOODCODE22')));
    // v2 is what the app exports now (#180).
    expect(xml, contains('<deskilo-workspace version="2">'));
    final parsed = parseWorkspaceXml(xml);
    expect(parsed.settings.name, 'Test Space');
    expect(parsed.settings.countryCode, 'DE');
    expect(parsed.settings.currencyCode, 'EUR');
    expect(parsed.settings.timezone, 'Europe/Berlin');
    // The WHOLE catalog exports — the inactive Docking station included.
    expect(
      parsed.accessories.map((a) => a.name),
      ['Monitor', 'Standing desk', 'Docking station'],
    );
    expect(parsed.accessories.first.supplementCents, 100);
    expect(parsed.accessories.last.active, false);
    expect(parsed.levels, hasLength(1));
    final level = parsed.levels.single;
    expect(level.name, 'Ground floor');
    final office = level.offices.single;
    expect(office.name, 'Main room');
    final desk = office.desks.single;
    expect(desk.name, 'Window desk');
    final seat = desk.seats.single;
    expect(seat.name, 'A1');
    expect(seat.orientation, SeatOrientation.n);
    // Legacy amenities keep exporting ALONGSIDE the catalog refs (#180).
    expect(seat.amenities, ['monitor']);
    expect(seat.accessoryNames, ['Monitor', 'Docking station']);
  });

  testWidgets('a failing save shows the generic error snackbar',
      (tester) async {
    await pumpWorkspaceSettings(
      tester,
      saver: ({required bytes, required fileName}) async =>
          throw Exception('disk full'),
    );

    final tile = find.byKey(const Key('workspaceSettingsExportXml'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}
