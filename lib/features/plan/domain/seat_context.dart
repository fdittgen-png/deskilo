// SPDX-License-Identifier: MIT

/// Where a reservation target lives on the floor plan (#182): the level,
/// office, desk and seat display names of one seat — or level + office only
/// for a whole-office reservation ([deskName]/[seatName] null then).
///
/// Pure Dart; resolved by the floor-plan repository so the calendar can
/// label a reservation without loading every level's plan.
class SeatContext {
  const SeatContext({
    required this.levelId,
    required this.levelName,
    required this.officeName,
    this.deskName,
    this.seatName,
  });

  final String levelId;
  final String levelName;
  final String officeName;
  final String? deskName;
  final String? seatName;

  /// "Level · Office · Desk · Seat" (skipping empty/absent parts) — the
  /// location line of the reservation detail sheet.
  String get locationLine => [levelName, officeName, deskName, seatName]
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .join(' · ');

  @override
  bool operator ==(Object other) =>
      other is SeatContext &&
      other.levelId == levelId &&
      other.levelName == levelName &&
      other.officeName == officeName &&
      other.deskName == deskName &&
      other.seatName == seatName;

  @override
  int get hashCode =>
      Object.hash(levelId, levelName, officeName, deskName, seatName);
}
