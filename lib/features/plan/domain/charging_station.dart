// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/system_columns.dart';

/// #2631 — the plug of a charging station, persisted by name — never
/// rename (the `connector` check of migration 0446).
enum ChargerConnector { type2, ccs, chademo, tesla, schuko }

/// #2631 — the charger of an EV parking slot (`charging_stations`, 0446).
/// One per slot: booking the slot books its charger, and a station that is
/// not [active] blocks the slot. The optional [accessoryId] is a priced
/// accessory of the workspace; it rides the slot through the existing
/// accessory-supplement path, so the statement bills the fee.
class ChargingStation implements SystemStamped {
  const ChargingStation({
    required this.id,
    required this.seatId,
    required this.connector,
    required this.powerKw,
    this.name = '',
    this.accessoryId,
    this.active = true,
    this.system = SystemColumns.none,
  });

  final String id;
  final String seatId;
  final ChargerConnector connector;
  final double powerKw;
  final String name;
  final String? accessoryId;
  final bool active;

  @override
  final SystemColumns system;

  ChargingStation copyWith({
    ChargerConnector? connector,
    double? powerKw,
    String? name,
    String? accessoryId,
    bool clearAccessory = false,
    bool? active,
  }) => ChargingStation(
    id: id,
    seatId: seatId,
    connector: connector ?? this.connector,
    powerKw: powerKw ?? this.powerKw,
    name: name ?? this.name,
    accessoryId: clearAccessory ? null : (accessoryId ?? this.accessoryId),
    active: active ?? this.active,
    system: system,
  );
}
