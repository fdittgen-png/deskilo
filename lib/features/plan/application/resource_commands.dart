// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/charging_station.dart';
import '../domain/charging_station_repository.dart';
import '../domain/grid_geometry.dart';
import '../domain/plan_resource_repository.dart';
import '../domain/seat.dart';

/// #2631 — saving a bookable resource of the plan together with its
/// charger. The order matters: a station that is no longer wanted goes
/// BEFORE the slot stops being EV (the server keeps a slot with a station
/// EV), a wanted one is written AFTER the slot is EV.
class ResourceCommands {
  const ResourceCommands(this._stations, this._resources);

  final ChargingStationRepository _stations;
  final PlanResourceRepository _resources;

  /// A meeting room or a parking slot on [deskId].
  Future<void> createResource({
    required String workspaceId,
    required String deskId,
    required String name,
    required ({int x, int y}) anchor,
    required SeatOrientation orientation,
    required NewResource resource,
  }) => _resources.createResource(
    workspaceId: workspaceId,
    deskId: deskId,
    name: name,
    anchor: anchor,
    orientation: orientation,
    resource: resource,
  );

  /// A parking area on [levelId].
  Future<void> createParkingArea({
    required String workspaceId,
    required String levelId,
    required String name,
    required int color,
    required GridRect rect,
  }) => _resources.createParkingArea(
    workspaceId: workspaceId,
    levelId: levelId,
    name: name,
    color: color,
    rect: rect,
  );

  /// Runs [updateSeat] and brings the slot's station to [wanted] (null: none).
  /// Returns whether a station was written or removed.
  Future<bool> save({
    required String workspaceId,
    required String seatId,
    required ChargingStation? existing,
    required ChargingStation? wanted,
    required Future<void> Function() updateSeat,
  }) async {
    if (existing != null && wanted == null) {
      await _stations.deleteStationOf(workspaceId, seatId);
    }
    await updateSeat();
    if (wanted != null) await _stations.saveStation(workspaceId, wanted);
    return existing != null || wanted != null;
  }
}
