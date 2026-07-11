// SPDX-License-Identifier: MIT
import 'accessory.dart';

/// Pure-Dart accessory-catalog boundary (#166, epic #163). Writes are
/// owner/admin-only (enforced by RLS `is_admin_of`; the UI additionally
/// hides catalog affordances from plain members).
abstract class AccessoryRepository {
  /// Accessories of the workspace, ordered by sort_order then name.
  /// The catalog editor (#167) passes [includeInactive].
  Future<List<Accessory>> fetchAccessories(
    String workspaceId, {
    bool includeInactive = false,
  });

  /// Owner/admin-only (RLS accessories_write): creates an accessory.
  Future<Accessory> createAccessory(
    String workspaceId, {
    required String name,
    int supplementCents = 0,
    int sortOrder = 0,
  });

  /// Owner/admin-only: partial update of name, supplement, active flag and
  /// sort order. Deactivate = `updateAccessory(active: false)` —
  /// accessories are never deleted (seat assignments and future bill
  /// lines reference them).
  Future<Accessory> updateAccessory(
    String accessoryId, {
    String? name,
    int? supplementCents,
    bool? active,
    int? sortOrder,
  });

  /// seat id → assigned accessory ids for the whole workspace (one fetch
  /// feeds the editor sheet #168 and the booking display #169). Seats
  /// without accessories are absent from the map.
  Future<Map<String, Set<String>>> fetchSeatAccessories(String workspaceId);

  /// Owner/admin-only: replaces the seat's accessory set (delete+insert).
  /// The database guards that seat and accessories share a workspace.
  Future<void> setSeatAccessories(String seatId, Set<String> accessoryIds);
}
