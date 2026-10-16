// SPDX-License-Identifier: AGPL-3.0-or-later
import 'charging_station.dart';

/// #2631 — the charging stations of the plan (0446). Members read them;
/// writing needs `manageSites` (RLS), like the layout.
abstract class ChargingStationRepository {
  /// seat id → its station, for the whole workspace.
  Future<Map<String, ChargingStation>> fetchStations(String workspaceId);

  /// Creates the slot's station or updates it (one per slot).
  Future<void> saveStation(String workspaceId, ChargingStation station);

  /// Removes the slot's station; no-op when it has none.
  Future<void> deleteStationOf(String workspaceId, String seatId);
}
