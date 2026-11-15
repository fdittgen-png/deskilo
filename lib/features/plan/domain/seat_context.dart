// SPDX-License-Identifier: AGPL-3.0-or-later

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
  /// #4054 — each name once: a seat named as its room ("Boardroom ·
  /// Boardroom table · Boardroom") is not said again.
  String get locationLine {
    final said = <String>{};
    return [levelName, officeName, deskName, seatName]
        .whereType<String>()
        .where((name) => name.isNotEmpty && said.add(name.trim().toLowerCase()))
        .join(' · ');
  }

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
