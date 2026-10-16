// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2631 — the Demo's in-memory meeting rooms, parking areas and charging
// stations: the plan editor and the reserve screen run on these exactly as
// they run on the server's rows.
import 'package:deskilo/features/plan/domain/charging_station.dart';
import 'package:deskilo/features/plan/domain/charging_station_repository.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/plan_resource_repository.dart';
import 'package:deskilo/features/plan/domain/seat.dart';

import 'floor_plan_repository.dart';

class FakePlanResourceRepository implements PlanResourceRepository {
  FakePlanResourceRepository(this._plan);

  final FakeFloorPlanRepository _plan;
  var _next = 1;

  @override
  Future<void> createResource({
    required String workspaceId,
    required String deskId,
    required String name,
    required ({int x, int y}) anchor,
    required SeatOrientation orientation,
    required NewResource resource,
  }) async {
    _plan.seats.add(
      Seat(
        id: 'resource-${_next++}',
        workspaceId: workspaceId,
        deskId: deskId,
        name: name,
        x: anchor.x,
        y: anchor.y,
        orientation: orientation,
        chair: '',
        amenities: const [],
        resourceKind: resource.kind,
        parkingKind: resource.parking,
        capacity: resource.capacity,
        slotMinutes: resource.kind == ResourceKind.room ? 60 : 1440,
      ),
    );
  }

  @override
  Future<void> createParkingArea({
    required String workspaceId,
    required String levelId,
    required String name,
    required int color,
    required GridRect rect,
  }) async {
    _plan.offices.add(
      Office(
        id: 'parking-area-${_next++}',
        workspaceId: workspaceId,
        levelId: levelId,
        name: name,
        color: color,
        bookableAsWhole: false,
        rect: rect,
        areaKind: AreaKind.parking,
      ),
    );
  }
}

class FakeChargingStationRepository implements ChargingStationRepository {
  /// seat id → its station.
  final stations = <String, ChargingStation>{};
  var _next = 1;

  @override
  Future<Map<String, ChargingStation>> fetchStations(
    String workspaceId,
  ) async => Map.of(stations);

  @override
  Future<void> saveStation(String workspaceId, ChargingStation station) async {
    final id = stations[station.seatId]?.id ?? 'charger-${_next++}';
    stations[station.seatId] = ChargingStation(
      id: id,
      seatId: station.seatId,
      connector: station.connector,
      powerKw: station.powerKw,
      name: station.name,
      accessoryId: station.accessoryId,
      active: station.active,
    );
  }

  @override
  Future<void> deleteStationOf(String workspaceId, String seatId) async {
    stations.remove(seatId);
  }
}
