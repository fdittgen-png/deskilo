// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/share/share_launcher.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

Future<void> pumpWorkspaceSettings(
  WidgetTester tester, {
  required ShareLauncher launcher,
}) async {
  // The settings form outgrew the 800×600 test viewport long ago (#155);
  // the export tile sits below Save, so keep the whole form built.
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final floorPlan = FakeFloorPlanRepository()..seedSmallPlan();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(floorPlan: floorPlan),
        shareLauncherProvider.overrideWithValue(launcher),
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
      'the export tile serializes settings + floor plan and hands an .xml '
      'file to the share sheet (#164)', (tester) async {
    final captured = <ShareParams>[];
    await pumpWorkspaceSettings(
      tester,
      launcher: (params) async => captured.add(params),
    );

    final tile = find.byKey(const Key('workspaceSettingsExportXml'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(captured, hasLength(1));
    expect(captured.single.fileNameOverrides, ['deskilo-test-space.xml']);
    final file = captured.single.files!.single;
    expect(file.mimeType, 'application/xml');

    // The payload round-trips through the pinned schema (#164): the
    // seeded ws-1 settings + the one-level plan, no ids, no invite code.
    final bytes = await tester.runAsync(() => file.readAsBytes());
    final xml = utf8.decode(bytes!);
    expect(xml, isNot(contains('GOODCODE22')));
    final parsed = parseWorkspaceXml(xml);
    expect(parsed.settings.name, 'Test Space');
    expect(parsed.settings.countryCode, 'DE');
    expect(parsed.settings.currencyCode, 'EUR');
    expect(parsed.settings.timezone, 'Europe/Berlin');
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
    expect(seat.amenities, ['monitor']);
  });

  testWidgets('a failing share shows the generic error snackbar',
      (tester) async {
    await pumpWorkspaceSettings(
      tester,
      launcher: (params) async => throw Exception('no share target'),
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
