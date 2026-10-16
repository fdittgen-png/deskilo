// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/features/enabled_feature_keys.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../domain/desk.dart';
import '../../domain/floor_plan.dart';
import '../../domain/grid_geometry.dart';
import '../../domain/office.dart';
import '../../domain/seat.dart';
import '../../providers/charging_station_providers.dart';

/// The feature keys the kinds live behind (`WorkspaceFeature.parking` and
/// `.meetingRooms`; a test pins both), read by key so the plan does not
/// import the workspace feature.
const String _parkingFeatureKey = 'parking';
const String _meetingRoomsFeatureKey = 'meetingRooms';

/// Which resource kinds the active workspace may create (their flags).
typedef ResourceFlags = ({bool parking, bool rooms});

/// The flags of the active workspace, read once by the editor.
ResourceFlags resourceFlagsOf(WidgetRef ref) {
  final keys = ref.read(enabledFeatureKeysProvider);
  return (
    parking: featureOn(keys, _parkingFeatureKey, byDefault: false),
    rooms: featureOn(keys, _meetingRoomsFeatureKey, byDefault: false),
  );
}

/// #2631 — what the seat tool places on a desk: a plain seat, a meeting
/// room or a parking slot. A room and a slot are rows of the same table as
/// a seat, their kind fixed here, so the plan editor asks once at creation
/// and only where the matching flag is on.
typedef PlacedResource = ({NewResource? resource, String namePrefix});

/// Default people a new meeting room holds, edited in its properties.
const int _defaultRoomCapacity = 6;

/// The kind of a NEW office. With the `parking` flag off there is nothing to
/// ask and the answer is a workspace area; null = dismissed.
Future<AreaKind?> chooseAreaKind(
  BuildContext context,
  ResourceFlags flags,
) async {
  if (!flags.parking) return AreaKind.workspace;
  final l10n = context.l10n;
  return showDialog<AreaKind>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.editorAreaKindTitle),
      children: [
        SimpleDialogOption(
          key: const ValueKey('editor-area-workspace'),
          onPressed: () => Navigator.of(context).pop(AreaKind.workspace),
          child: Text(l10n.editorAreaWorkspace),
        ),
        SimpleDialogOption(
          key: const ValueKey('editor-area-parking'),
          onPressed: () => Navigator.of(context).pop(AreaKind.parking),
          child: Text(l10n.editorAreaParking),
        ),
      ],
    ),
  );
}

/// What the seat tool creates on [desk]: a parking slot in a parking area
/// (the only thing it holds), a seat — or, with the `meetingRooms` flag on,
/// a choice between a seat and a meeting room — in a workspace area. Null =
/// dismissed.
Future<PlacedResource?> chooseNewResource(
  BuildContext context,
  ResourceFlags flags, {
  required FloorPlan plan,
  required Desk desk,
}) async {
  final l10n = context.l10n;
  final area = plan.offices
      .where((o) => o.id == desk.officeId)
      .map((o) => o.areaKind)
      .firstOrNull;
  if (area == AreaKind.parking) {
    return (
      resource: (
        kind: ResourceKind.parking,
        parking: ParkingKind.standard,
        capacity: null,
      ),
      namePrefix: l10n.editorParkingSlotNameDefault,
    );
  }
  final seat = (resource: null, namePrefix: l10n.editorSeatNameDefault);
  if (!flags.rooms) return seat;
  final kind = await showDialog<ResourceKind>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.editorResourceKindTitle),
      children: [
        SimpleDialogOption(
          key: const ValueKey('editor-resource-seat'),
          onPressed: () => Navigator.of(context).pop(ResourceKind.seat),
          child: Text(l10n.editorResourceSeat),
        ),
        SimpleDialogOption(
          key: const ValueKey('editor-resource-room'),
          onPressed: () => Navigator.of(context).pop(ResourceKind.room),
          child: Text(l10n.editorResourceRoom),
        ),
      ],
    ),
  );
  return switch (kind) {
    null => null,
    ResourceKind.room => (
      resource: (
        kind: ResourceKind.room,
        parking: null,
        capacity: _defaultRoomCapacity,
      ),
      namePrefix: l10n.editorRoomNameDefault,
    ),
    _ => seat,
  };
}

/// Creates [placed] on [deskId] at [anchor] (a meeting room or a parking
/// slot; a plain seat goes through the floor-plan repository).
Future<void> placeResource(
  WidgetRef ref, {
  required String workspaceId,
  required String deskId,
  required String name,
  required ({int x, int y}) anchor,
  required NewResource resource,
}) => ref
    .read(resourceCommandsProvider)
    .createResource(
      workspaceId: workspaceId,
      deskId: deskId,
      name: name,
      anchor: anchor,
      orientation: SeatOrientation.n,
      resource: resource,
    );

/// Creates a parking area on [levelId].
Future<void> placeParkingArea(
  WidgetRef ref, {
  required String workspaceId,
  required String levelId,
  required String name,
  required int color,
  required GridRect rect,
}) => ref
    .read(resourceCommandsProvider)
    .createParkingArea(
      workspaceId: workspaceId,
      levelId: levelId,
      name: name,
      color: color,
      rect: rect,
    );
