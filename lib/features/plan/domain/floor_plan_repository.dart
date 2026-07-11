// SPDX-License-Identifier: MIT
import 'desk.dart';
import 'floor_plan.dart';
import 'grid_geometry.dart';
import 'level.dart';
import 'office.dart';
import 'seat.dart';
import 'seat_context.dart';

/// Pure-Dart floor-plan boundary. Writes are owner-only (enforced by RLS;
/// the UI additionally hides editor affordances from non-owners).
abstract class FloorPlanRepository {
  Future<List<Level>> fetchLevels(String workspaceId);
  Future<Level> createLevel(String workspaceId, String name, int sortOrder);
  Future<void> renameLevel(String levelId, String name);
  Future<void> deleteLevel(String levelId);

  /// Persists a new level order; index in [orderedLevelIds] becomes sort_order.
  Future<void> reorderLevels(List<String> orderedLevelIds);

  /// seat/office id → display name across the whole workspace (calendar and
  /// event lists label bookings without loading every level's plan).
  Future<Map<String, String>> fetchTargetNames(String workspaceId);

  /// Resolves where [seatId] lives (#182): level · office · desk · seat
  /// names for the reservation detail sheet. Null when the seat (or any
  /// link of its chain) no longer exists.
  Future<SeatContext?> fetchSeatContext(String seatId);

  /// [fetchSeatContext] for a whole-office reservation: level + office
  /// names only ([SeatContext.deskName]/[SeatContext.seatName] null).
  Future<SeatContext?> fetchOfficeContext(String officeId);

  Future<FloorPlan> fetchPlan(String levelId);

  Future<Office> createOffice({
    required String workspaceId,
    required String levelId,
    required String name,
    required int color,
    required bool bookableAsWhole,
    required GridRect rect,
  });
  Future<void> updateOffice(Office office);
  Future<void> deleteOffice(String officeId);

  Future<Desk> createDesk({
    required String workspaceId,
    required String officeId,
    required String name,
    required GridRect rect,
  });
  Future<void> updateDesk(Desk desk);
  Future<void> deleteDesk(String deskId);

  Future<Seat> createSeat({
    required String workspaceId,
    required String deskId,
    required String name,
    required int x,
    required int y,
    required SeatOrientation orientation,
  });
  Future<void> updateSeat(Seat seat);
  Future<void> deleteSeat(String seatId);

  /// Sets or clears the seat's maintenance block (#161). [from] set with
  /// [to] null blocks open-endedly; both null makes the seat reservable
  /// again. Permission (owner, or admin with the adminSeatBlocking
  /// feature) is enforced server-side by the set_seat_block RPC.
  Future<void> setSeatBlock(String seatId, {DateTime? from, DateTime? to});
}
