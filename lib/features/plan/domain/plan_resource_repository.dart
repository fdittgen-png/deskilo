// SPDX-License-Identifier: AGPL-3.0-or-later
import 'grid_geometry.dart';
import 'seat.dart';

/// #2631 — creating the plan's meeting rooms and parking: a room and a
/// parking slot are rows of the seats table whose kind is fixed at creation,
/// a parking area is an office whose kind is fixed at creation. Both kinds
/// live behind a feature flag the server enforces (`meetingRooms`,
/// `parking`); the floor-plan repository's cache is invalidated by each
/// write.
abstract class PlanResourceRepository {
  /// A meeting room or a parking slot on [deskId].
  Future<void> createResource({
    required String workspaceId,
    required String deskId,
    required String name,
    required ({int x, int y}) anchor,
    required SeatOrientation orientation,
    required NewResource resource,
  });

  /// A parking area: an office that holds parking slots and no seat.
  Future<void> createParkingArea({
    required String workspaceId,
    required String levelId,
    required String name,
    required int color,
    required GridRect rect,
  });
}
