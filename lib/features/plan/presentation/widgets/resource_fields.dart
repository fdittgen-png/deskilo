// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/accessory.dart';
import '../../domain/charging_station.dart';
import '../../domain/seat.dart';
import '../../providers/charging_station_providers.dart';

/// #2631 — what the seat properties sheet edits beyond a plain seat: the
/// resource's own booking slot (any kind), a room's capacity, a parking
/// slot's kind and the charger of an EV slot. The sheet owns one draft;
/// [ResourceFields] mutates it and the sheet reads it on save.
class ResourceDraft {
  ResourceDraft(Seat seat, ChargingStation? station)
    : slotMinutes = seat.slotMinutes,
      parkingKind = seat.parkingKind,
      capacity = TextEditingController(text: '${seat.capacity ?? ''}'),
      station = station,
      charger = station != null,
      connector = station?.connector ?? ChargerConnector.type2,
      power = TextEditingController(
        text: station == null ? '' : _kw(station.powerKw),
      ),
      accessoryId = station?.accessoryId,
      chargerActive = station?.active ?? true;

  static String _kw(double kw) =>
      kw == kw.roundToDouble() ? '${kw.round()}' : '$kw';

  /// The slots a resource can be booked in (null = the workspace's value).
  static const slots = <int?>[null, 15, 30, 60, 1440];

  int? slotMinutes;
  ParkingKind? parkingKind;
  final TextEditingController capacity;
  final ChargingStation? station;
  bool charger;
  ChargerConnector connector;
  final TextEditingController power;
  String? accessoryId;
  bool chargerActive;

  /// A room's capacity, or null for anything else (or an empty field).
  int? get capacityValue => int.tryParse(capacity.text.trim());

  /// The charger to keep: only an EV slot with its switch on has one.
  bool get wantsCharger => parkingKind == ParkingKind.ev && charger;

  /// The station this draft asks for on [seatId], or null for none.
  ChargingStation? wanted(String seatId) {
    final kw = powerKw;
    if (!wantsCharger || kw == null) return null;
    final base =
        station ??
        ChargingStation(
          id: '',
          seatId: seatId,
          connector: connector,
          powerKw: kw,
        );
    return base.copyWith(
      connector: connector,
      powerKw: kw,
      accessoryId: accessoryId,
      clearAccessory: accessoryId == null,
      active: chargerActive,
    );
  }

  double? get powerKw {
    final kw = double.tryParse(power.text.trim().replaceAll(',', '.'));
    return kw == null || kw <= 0 || kw > 1000 ? null : kw;
  }
}

/// The sheet's draft of [seat]: its station is read for an EV slot.
Future<ResourceDraft> loadResourceDraft(WidgetRef ref, Seat seat) async {
  final stations = seat.resourceKind == ResourceKind.parking
      ? await ref.read(chargingStationsProvider(seat.workspaceId).future)
      : const <String, ChargingStation>{};
  return ResourceDraft(seat, stations[seat.id]);
}

/// Saves the seat with [updateSeat] and brings its charger to the draft.
Future<void> saveResourceDraft(
  WidgetRef ref, {
  required Seat seat,
  required ResourceDraft draft,
  required Future<void> Function() updateSeat,
}) async {
  final changed = await ref
      .read(resourceCommandsProvider)
      .save(
        workspaceId: seat.workspaceId,
        seatId: seat.id,
        existing: draft.station,
        wanted: draft.wanted(seat.id),
        updateSeat: updateSeat,
      );
  if (changed) ref.invalidate(chargingStationsProvider(seat.workspaceId));
}

/// Chip label: accessory name, plus its per-half-day supplement when one is
/// set (shared by the seat's equipment chips and a charger's fee choice).
String accessoryChoiceLabel(Accessory accessory, String? supplement) =>
    supplement == null ? accessory.name : '${accessory.name} (+$supplement)';

String _slotLabel(BuildContext context, int? minutes) {
  final l10n = context.l10n;
  return switch (minutes) {
    15 => l10n.editorSlot15,
    30 => l10n.editorSlot30,
    60 => l10n.editorSlot60,
    1440 => l10n.editorSlotDay,
    _ => l10n.editorSlotWorkspace,
  };
}

String _connectorLabel(BuildContext context, ChargerConnector connector) {
  final l10n = context.l10n;
  return switch (connector) {
    ChargerConnector.type2 => l10n.editorConnectorType2,
    ChargerConnector.ccs => l10n.editorConnectorCcs,
    ChargerConnector.chademo => l10n.editorConnectorChademo,
    ChargerConnector.tesla => l10n.editorConnectorTesla,
    ChargerConnector.schuko => l10n.editorConnectorSchuko,
  };
}

/// The resource section of the seat properties sheet.
class ResourceFields extends StatefulWidget {
  const ResourceFields({
    super.key,
    required this.seat,
    required this.draft,
    required this.catalog,
    required this.accessoryLabel,
    this.showSlot = true,
  });

  final Seat seat;
  final ResourceDraft draft;

  /// The workspace's accessories a charger's usage fee can name.
  final List<Accessory> catalog;
  final String Function(Accessory accessory) accessoryLabel;

  /// A plain seat offers its own slot only where rooms or parking exist.
  final bool showSlot;

  @override
  State<ResourceFields> createState() => _ResourceFieldsState();
}

class _ResourceFieldsState extends State<ResourceFields> {
  ResourceDraft get _draft => widget.draft;

  void _set(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isRoom = widget.seat.resourceKind == ResourceKind.room;
    final isParking = widget.seat.resourceKind == ResourceKind.parking;
    final feeValue = widget.catalog.any((a) => a.id == _draft.accessoryId)
        ? _draft.accessoryId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRoom) ...[
          AppTextField(
            key: const ValueKey('editor-room-capacity'),
            controller: _draft.capacity,
            keyboardType: TextInputType.number,
            label: l10n.editorRoomCapacityLabel,
          ),
          const FormGap(),
        ],
        if (isParking) ...[
          Text(l10n.editorParkingKindLabel),
          const FormGap.small(),
          SegmentedButton<ParkingKind>(
            key: const ValueKey('editor-parking-kind'),
            segments: [
              ButtonSegment(
                value: ParkingKind.standard,
                label: Text(l10n.editorParkingStandard),
              ),
              ButtonSegment(
                value: ParkingKind.ev,
                label: Text(l10n.editorParkingEv),
              ),
              ButtonSegment(
                value: ParkingKind.accessible,
                label: Text(l10n.editorParkingAccessible),
              ),
            ],
            selected: {_draft.parkingKind ?? ParkingKind.standard},
            onSelectionChanged: (s) => _set(() => _draft.parkingKind = s.first),
          ),
          const FormGap(),
        ],
        if (widget.showSlot || isRoom || isParking) ...[
          DropdownButtonFormField<int?>(
            key: const ValueKey('editor-slot-minutes'),
            initialValue: ResourceDraft.slots.contains(_draft.slotMinutes)
                ? _draft.slotMinutes
                : null,
            decoration: InputDecoration(labelText: l10n.editorSlotLabel),
            items: [
              for (final m in ResourceDraft.slots)
                DropdownMenuItem<int?>(
                  value: m,
                  child: Text(_slotLabel(context, m)),
                ),
            ],
            onChanged: (m) => _set(() => _draft.slotMinutes = m),
          ),
          const FormGap(),
        ],
        if (_draft.parkingKind == ParkingKind.ev) ...[
          SwitchListTile(
            key: const ValueKey('editor-charger-enabled'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.editorChargerEnabled),
            value: _draft.charger,
            onChanged: (v) => _set(() => _draft.charger = v),
          ),
          if (_draft.charger) ...[
            DropdownButtonFormField<ChargerConnector>(
              key: const ValueKey('editor-charger-connector'),
              initialValue: _draft.connector,
              decoration: InputDecoration(
                labelText: l10n.editorChargerConnector,
              ),
              items: [
                for (final c in ChargerConnector.values)
                  DropdownMenuItem(
                    value: c,
                    child: Text(_connectorLabel(context, c)),
                  ),
              ],
              onChanged: (c) =>
                  _set(() => _draft.connector = c ?? _draft.connector),
            ),
            const FormGap.small(),
            AppTextField(
              key: const ValueKey('editor-charger-power'),
              controller: _draft.power,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              label: l10n.editorChargerPower,
            ),
            if (widget.catalog.isNotEmpty) ...[
              const FormGap.small(),
              DropdownButtonFormField<String?>(
                key: const ValueKey('editor-charger-fee'),
                initialValue: feeValue,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.editorChargerFee),
                items: [
                  DropdownMenuItem<String?>(
                    child: Text(l10n.editorChargerFeeNone),
                  ),
                  for (final a in widget.catalog)
                    DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(widget.accessoryLabel(a)),
                    ),
                ],
                onChanged: (id) => _set(() => _draft.accessoryId = id),
              ),
            ],
            SwitchListTile(
              key: const ValueKey('editor-charger-active'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.editorChargerInService),
              value: _draft.chargerActive,
              onChanged: (v) => _set(() => _draft.chargerActive = v),
            ),
          ],
          const FormGap(),
        ],
      ],
    );
  }
}
