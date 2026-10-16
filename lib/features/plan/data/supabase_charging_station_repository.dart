// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enum_wire.dart';
import '../../../core/data/system_columns.dart';
import '../domain/charging_station.dart';
import '../domain/charging_station_repository.dart';

class SupabaseChargingStationRepository implements ChargingStationRepository {
  SupabaseChargingStationRepository(this._client);

  final SupabaseClient _client;

  ChargingStation _fromRow(Map<String, Object?> row) => ChargingStation(
    system: SystemColumns.fromRow(row),
    id: row['id'] as String,
    seatId: row['seat_id'] as String,
    name: row['name'] as String? ?? '',
    connector: enumOr(
      ChargerConnector.values,
      row['connector'] as String?,
      ChargerConnector.type2,
      area: 'plan',
    ),
    powerKw: (row['power_kw'] as num).toDouble(),
    accessoryId: row['accessory_id'] as String?,
    active: row['active'] as bool? ?? true,
  );

  @override
  Future<Map<String, ChargingStation>> fetchStations(String workspaceId) async {
    final rows = await _client
        .from('charging_stations')
        .select()
        .eq('workspace_id', workspaceId);
    return {for (final row in rows) row['seat_id'] as String: _fromRow(row)};
  }

  @override
  Future<void> saveStation(String workspaceId, ChargingStation station) =>
      _client.from('charging_stations').upsert({
        'workspace_id': workspaceId,
        'seat_id': station.seatId,
        'name': station.name,
        'connector': station.connector.name,
        'power_kw': station.powerKw,
        'accessory_id': station.accessoryId,
        'active': station.active,
      }, onConflict: 'seat_id');

  @override
  Future<void> deleteStationOf(String workspaceId, String seatId) => _client
      .from('charging_stations')
      .delete()
      .eq('workspace_id', workspaceId)
      .eq('seat_id', seatId);
}
