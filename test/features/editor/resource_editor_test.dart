// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2631 checkpoint 5 — the plan editor defines meeting rooms, parking
// areas, parking slots and their chargers, each behind its flag.
import 'package:deskilo/core/demo/data/plan_resource_repository.dart';
import 'package:deskilo/features/plan/domain/charging_station.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/level_canvas.dart'
    show cellCenter, pumpCanvas, seedOffice;

final _chargers = FakeChargingStationRepository();

Future<FakeFloorPlanRepository> _pump(
  WidgetTester tester, {
  Set<String> flags = const {},
  Future<void> Function(FakeFloorPlanRepository plans, String levelId)? seed,
}) => pumpCanvas(
  tester,
  seed: seed,
  workspace: FakeWorkspaceRepository.withWorkspace(
    featureFlags: {for (final f in flags) f: true},
  ),
  chargingStations: _chargers,
);

Future<String> _desk(FakeFloorPlanRepository plans, String officeId) async =>
    (await plans.createDesk(
      workspaceId: 'ws-1',
      officeId: officeId,
      name: 'Desk',
      rect: const GridRect(x: 4, y: 4, w: 12, h: 8),
    )).id;

void main() {
  testWidgets('meetingRooms on: the seat tool offers a room, kept as a room '
      'with its capacity and the hour slot', (tester) async {
    final plans = await _pump(
      tester,
      flags: {'meetingRooms'},
      seed: (plans, levelId) async {
        await seedOffice(plans, levelId);
        await _desk(plans, plans.offices.single.id);
      },
    );
    await tester.tap(find.text('Seat'));
    await tester.pumpAndSettle();
    await tester.tapAt(cellCenter(tester, 5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-resource-room')));
    await tester.pumpAndSettle();

    final room = plans.seats.single;
    expect(room.resourceKind, ResourceKind.room);
    expect(room.capacity, 6);
    expect(room.slotMinutes, 60);
  });

  testWidgets('meetingRooms off: the seat tool places a seat without asking', (
    tester,
  ) async {
    final plans = await _pump(
      tester,
      seed: (plans, levelId) async {
        await seedOffice(plans, levelId);
        await _desk(plans, plans.offices.single.id);
      },
    );
    await tester.tap(find.text('Seat'));
    await tester.pumpAndSettle();
    await tester.tapAt(cellCenter(tester, 5, 5));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-resource-room')), findsNothing);
    expect(plans.seats.single.resourceKind, ResourceKind.seat);
  });

  testWidgets('a desk of a parking area takes parking slots, never seats', (
    tester,
  ) async {
    final plans = await _pump(
      tester,
      flags: {'parking'},
      seed: (plans, levelId) async {
        await FakePlanResourceRepository(plans).createParkingArea(
          workspaceId: 'ws-1',
          levelId: levelId,
          name: 'Garage',
          color: 0,
          rect: const GridRect(x: 0, y: 0, w: 40, h: 30),
        );
        await _desk(plans, plans.offices.single.id);
      },
    );
    expect(plans.offices.single.areaKind, AreaKind.parking);
    await tester.tap(find.text('Seat'));
    await tester.pumpAndSettle();
    await tester.tapAt(cellCenter(tester, 5, 5));
    await tester.pumpAndSettle();

    final slot = plans.seats.single;
    expect(slot.resourceKind, ResourceKind.parking);
    expect(slot.parkingKind, ParkingKind.standard);
    expect(slot.slotMinutes, 1440);
  });

  testWidgets('an EV slot gets its charger from the properties sheet', (
    tester,
  ) async {
    _chargers.stations.clear();
    final plans = await _pump(
      tester,
      flags: {'parking'},
      seed: (plans, levelId) async {
        final resources = FakePlanResourceRepository(plans);
        await resources.createParkingArea(
          workspaceId: 'ws-1',
          levelId: levelId,
          name: 'Garage',
          color: 0,
          rect: const GridRect(x: 0, y: 0, w: 40, h: 30),
        );
        final deskId = await _desk(plans, plans.offices.single.id);
        await resources.createResource(
          workspaceId: 'ws-1',
          deskId: deskId,
          name: 'P1',
          anchor: (x: 4, y: 4),
          orientation: SeatOrientation.n,
          resource: (
            kind: ResourceKind.parking,
            parking: ParkingKind.ev,
            capacity: null,
          ),
        );
      },
    );
    await tester.tapAt(cellCenter(tester, 5, 5));
    await tester.pumpAndSettle();
    await tester.tapAt(cellCenter(tester, 5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Parking slot'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('editor-charger-enabled')),
    );
    await tester.tap(find.byKey(const ValueKey('editor-charger-enabled')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('editor-charger-power')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-charger-power')),
      '22',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final station = _chargers.stations[plans.seats.single.id]!;
    expect(station.powerKw, 22);
    expect(station.connector, ChargerConnector.type2);
    expect(plans.seats.single.parkingKind, ParkingKind.ev);
  });

  testWidgets('a slot that stops being EV loses its charger', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _chargers.stations.clear();
    late String seatId;
    final plans = await _pump(
      tester,
      flags: {'parking'},
      seed: (plans, levelId) async {
        final resources = FakePlanResourceRepository(plans);
        await resources.createParkingArea(
          workspaceId: 'ws-1',
          levelId: levelId,
          name: 'Garage',
          color: 0,
          rect: const GridRect(x: 0, y: 0, w: 40, h: 30),
        );
        final deskId = await _desk(plans, plans.offices.single.id);
        await resources.createResource(
          workspaceId: 'ws-1',
          deskId: deskId,
          name: 'P1',
          anchor: (x: 4, y: 4),
          orientation: SeatOrientation.n,
          resource: (
            kind: ResourceKind.parking,
            parking: ParkingKind.ev,
            capacity: null,
          ),
        );
        seatId = plans.seats.single.id;
        await _chargers.saveStation(
          'ws-1',
          ChargingStation(
            id: '',
            seatId: seatId,
            connector: ChargerConnector.ccs,
            powerKw: 50,
          ),
        );
      },
    );
    await tester.tapAt(cellCenter(tester, 5, 5));
    await tester.pumpAndSettle();
    await tester.tapAt(cellCenter(tester, 5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-charger-power')), findsOneWidget);

    await tester.tap(find.text('Standard'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(_chargers.stations, isEmpty);
    expect(plans.seats.single.parkingKind, ParkingKind.standard);
  });
}
