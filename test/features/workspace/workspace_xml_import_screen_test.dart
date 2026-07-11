// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_import.dart';
import 'package:deskilo/features/workspace/domain/workspace_xml.dart';
import 'package:deskilo/features/workspace/providers/workspace_import_providers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

/// Import boundary fake (fakes over mocks): records calls, optionally
/// throws. Own class here — the shared helpers stay untouched (#165).
class RecordingImportRepository implements WorkspaceImportRepository {
  final calls = <(String workspaceId, WorkspaceXmlData data)>[];

  /// When set, [importFloorPlan] throws it instead of recording.
  Object? error;

  @override
  Future<void> importFloorPlan(String workspaceId, WorkspaceXmlData data) async {
    final e = error;
    if (e != null) throw e;
    calls.add((workspaceId, data));
  }
}

/// Counts [fetchLevels] so the test can assert the import invalidated the
/// floor-plan chain (a cached keepAlive provider would never refetch).
class CountingFloorPlanRepository extends FakeFloorPlanRepository {
  int fetchLevelsCalls = 0;

  @override
  Future<List<Level>> fetchLevels(String workspaceId) {
    fetchLevelsCalls++;
    return super.fetchLevels(workspaceId);
  }
}

/// A valid exported file: FR settings (differing from the seeded ws-1 so
/// the apply is observable), one level, one office, one desk, two seats.
String importableXml() {
  const workspace = Workspace(
    id: 'ws-import',
    name: 'Imported Space',
    countryCode: 'FR',
    currencyCode: 'EUR',
    timezone: 'Europe/Paris',
    inviteCode: 'IRRELEVANT1',
    featureFlags: {'adminSeatBlocking': true},
    paymentInstructions: {'iban': 'FR76 1234', 'reference': 'DesKilo ref'},
  );
  const level = Level(
    id: 'level-x',
    workspaceId: 'ws-import',
    name: 'First floor',
    sortOrder: 0,
  );
  const office = Office(
    id: 'office-x',
    workspaceId: 'ws-import',
    levelId: 'level-x',
    name: 'Quiet room',
    color: 1,
    bookableAsWhole: false,
    rect: GridRect(x: 0, y: 0, w: 30, h: 20),
  );
  const desk = Desk(
    id: 'desk-x',
    workspaceId: 'ws-import',
    officeId: 'office-x',
    name: 'Long desk',
    rect: GridRect(x: 2, y: 2, w: 14, h: 4),
  );
  const seats = [
    Seat(
      id: 'seat-x1',
      workspaceId: 'ws-import',
      deskId: 'desk-x',
      name: 'B1',
      x: 2,
      y: 2,
      orientation: SeatOrientation.n,
      chair: 'standard',
      amenities: ['monitor'],
    ),
    Seat(
      id: 'seat-x2',
      workspaceId: 'ws-import',
      deskId: 'desk-x',
      name: 'B2',
      x: 8,
      y: 2,
      orientation: SeatOrientation.n,
      chair: '',
      amenities: [],
    ),
  ];
  return buildWorkspaceXml(
    workspace: workspace,
    levels: [
      (
        level: level,
        plan: FloorPlan(
          levelId: level.id,
          offices: [office],
          desks: [desk],
          seats: seats,
        ),
      ),
    ],
  );
}

XFile xmlFile(String content) => XFile.fromData(
      utf8.encode(content),
      mimeType: 'application/xml',
      name: 'deskilo-imported-space.xml',
    );

Future<void> pumpWorkspaceSettings(
  WidgetTester tester, {
  required FilePicker picker,
  required RecordingImportRepository importRepository,
  required FakeWorkspaceRepository workspaceRepository,
  required CountingFloorPlanRepository floorPlan,
}) async {
  // The settings form outgrew the 800×600 test viewport long ago (#155);
  // the import tile sits below the export tile, keep the form built.
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: workspaceRepository,
          floorPlan: floorPlan,
        ),
        filePickerProvider.overrideWithValue(picker),
        workspaceImportRepositoryProvider.overrideWithValue(importRepository),
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

Future<void> tapImportTile(WidgetTester tester) async {
  final tile = find.byKey(const Key('workspaceSettingsImportXml'));
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'pick → preview counts → confirm applies the plan via the repo, the '
      'settings via the existing writers, and refreshes the floor-plan '
      'providers (#165)', (tester) async {
    final importRepository = RecordingImportRepository();
    final workspaceRepository = FakeWorkspaceRepository.withWorkspace();
    final floorPlan = CountingFloorPlanRepository()..seedSmallPlan();
    final requestedTypeGroups = <XTypeGroup>[];
    await pumpWorkspaceSettings(
      tester,
      picker: (typeGroup) async {
        requestedTypeGroups.add(typeGroup);
        return xmlFile(importableXml());
      },
      importRepository: importRepository,
      workspaceRepository: workspaceRepository,
      floorPlan: floorPlan,
    );
    final container =
        ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
    await container.read(levelsProvider.future);
    final levelFetchesBefore = floorPlan.fetchLevelsCalls;

    await tapImportTile(tester);

    // The picker was filtered to XML files.
    expect(requestedTypeGroups.single.extensions, ['xml']);

    // Preview dialog: counts + destructive warning, nothing applied yet.
    expect(find.text('Replace floor plan?'), findsOneWidget);
    expect(
      find.text('Levels: 1 · Offices: 1 · Desks: 1 · Seats: 2'),
      findsOneWidget,
    );
    expect(importRepository.calls, isEmpty);

    await tester.tap(find.byKey(const Key('workspaceXmlImportConfirm')));
    await tester.pumpAndSettle();

    // Floor plan went through the transactional RPC boundary...
    final (workspaceId, data) = importRepository.calls.single;
    expect(workspaceId, 'ws-1');
    expect(data.levels.single.name, 'First floor');
    expect(data.levels.single.offices.single.desks.single.seats, hasLength(2));

    // ...settings through the EXISTING owner writers (#153/#155/#146)...
    expect(
      workspaceRepository.lastLocaleUpdate,
      ['ws-1', 'FR', 'EUR', 'Europe/Paris'],
    );
    expect(workspaceRepository.lastPaymentInstructions?.iban, 'FR76 1234');
    expect(
      workspaceRepository.lastPaymentInstructions?.reference,
      'DesKilo ref',
    );
    expect(
      workspaceRepository.workspaces.single.featureFlags['adminSeatBlocking'],
      true,
    );

    // ...and the floor-plan chain was invalidated: a fresh read refetches
    // instead of serving the keepAlive cache.
    expect(find.text('Workspace imported.'), findsOneWidget);
    await container.read(levelsProvider.future);
    expect(floorPlan.fetchLevelsCalls, greaterThan(levelFetchesBefore));
  });

  testWidgets('cancelling the preview applies nothing', (tester) async {
    final importRepository = RecordingImportRepository();
    final workspaceRepository = FakeWorkspaceRepository.withWorkspace();
    await pumpWorkspaceSettings(
      tester,
      picker: (typeGroup) async => xmlFile(importableXml()),
      importRepository: importRepository,
      workspaceRepository: workspaceRepository,
      floorPlan: CountingFloorPlanRepository()..seedSmallPlan(),
    );

    await tapImportTile(tester);
    await tester.tap(find.byKey(const Key('workspaceXmlImportCancel')));
    await tester.pumpAndSettle();

    expect(importRepository.calls, isEmpty);
    expect(workspaceRepository.lastLocaleUpdate, isNull);
    expect(find.text('Workspace imported.'), findsNothing);
  });

  testWidgets('an unparseable file shows the mapped message and never '
      'reaches the preview (#165)', (tester) async {
    final importRepository = RecordingImportRepository();
    await pumpWorkspaceSettings(
      tester,
      picker: (typeGroup) async => xmlFile('this is not xml <<<'),
      importRepository: importRepository,
      workspaceRepository: FakeWorkspaceRepository.withWorkspace(),
      floorPlan: CountingFloorPlanRepository()..seedSmallPlan(),
    );

    await tapImportTile(tester);

    expect(find.text('The file is not readable XML.'), findsOneWidget);
    expect(find.text('Replace floor plan?'), findsNothing);
    expect(importRepository.calls, isEmpty);
  });

  testWidgets('a newer schema version maps to its own message',
      (tester) async {
    final importRepository = RecordingImportRepository();
    await pumpWorkspaceSettings(
      tester,
      picker: (typeGroup) async =>
          xmlFile('<deskilo-workspace version="99"></deskilo-workspace>'),
      importRepository: importRepository,
      workspaceRepository: FakeWorkspaceRepository.withWorkspace(),
      floorPlan: CountingFloorPlanRepository()..seedSmallPlan(),
    );

    await tapImportTile(tester);

    expect(
      find.text('The file was exported by a newer version of DesKilo and '
          'cannot be imported.'),
      findsOneWidget,
    );
    expect(importRepository.calls, isEmpty);
  });

  testWidgets("the RPC's reservation guard maps to its own clear message "
      'and skips the settings writers (#165)', (tester) async {
    final importRepository = RecordingImportRepository()
      ..error = const PostgrestException(message: kWorkspaceHasReservationsError);
    final workspaceRepository = FakeWorkspaceRepository.withWorkspace();
    await pumpWorkspaceSettings(
      tester,
      picker: (typeGroup) async => xmlFile(importableXml()),
      importRepository: importRepository,
      workspaceRepository: workspaceRepository,
      floorPlan: CountingFloorPlanRepository()..seedSmallPlan(),
    );

    await tapImportTile(tester);
    await tester.tap(find.byKey(const Key('workspaceXmlImportConfirm')));
    await tester.pumpAndSettle();

    expect(
      find.text('This workspace already has reservations, so its floor plan '
          'cannot be replaced. Imports are only possible before the first '
          'booking.'),
      findsOneWidget,
    );
    // Plan-first ordering: the refused RPC left the settings untouched.
    expect(workspaceRepository.lastLocaleUpdate, isNull);
    expect(workspaceRepository.lastPaymentInstructions, isNull);
  });
}
