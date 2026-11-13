// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — what the desk calendar reads for a period: the bookings,
// the plans of every level, the names and levels of the places and the kind
// of each seat. One read feeds the grid and the records table, so the two
// show the same bookings. The bookings come from the month reads the other
// calendar surfaces use, so a booking made anywhere refreshes this too.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/plan/domain/floor_plan.dart';
import '../../features/plan/domain/level.dart';
import '../../features/plan/domain/seat.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/domain/reservation.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import 'desk_calendar.dart';

/// Everything the desk calendar draws for one period.
class DeskCalendarData {
  const DeskCalendarData({
    required this.reservations,
    required this.levels,
    required this.plans,
    required this.names,
    required this.levelOf,
  });

  /// Every booking read for the months the period touches, any state.
  final List<Reservation> reservations;
  final List<Level> levels;
  final List<FloorPlan> plans;

  /// Place id → name.
  final Map<String, String> names;

  /// Seat, desk and office id → level id.
  final Map<String, String> levelOf;

  /// The kind of every seat, by id.
  Map<String, ResourceKind> get kindOf => {
    for (final plan in plans)
      for (final seat in plan.seats) seat.id: seat.resourceKind,
  };

  DeskPlaceFacts get facts => (levelOf: levelOf, kindOf: kindOf);
}

/// The first day of each month the period [span] touches, as the
/// `YYYY-MM` keys the month reads take.
List<String> _deskMonthKeys(DeskSpan span) {
  final keys = <String>[];
  var month = DateTime(span.from.year, span.from.month);
  while (month.isBefore(span.to)) {
    keys.add(monthKeyOf(month));
    month = DateTime(month.year, month.month + 1);
  }
  return keys;
}

/// The desk calendar's read of [span] (date-only, half-open).
final deskCalendarDataProvider = FutureProvider.autoDispose
    .family<DeskCalendarData, DeskSpan>((ref, span) async {
      final reads = [
        for (final key in _deskMonthKeys(span))
          ref.watch(reservationsForMonthProvider(key).future),
      ];
      final levels = await ref.watch(levelsProvider.future);
      final plans = [
        for (final level in levels)
          ref.watch(floorPlanProvider(level.id).future),
      ];
      final names = ref.watch(targetNamesProvider.future);
      final levelOf = ref.watch(targetLevelsProvider.future);
      return DeskCalendarData(
        reservations: [for (final read in reads) ...await read],
        levels: levels,
        plans: await Future.wait(plans),
        names: await names,
        levelOf: await levelOf,
      );
    });

/// The booking [id] as it stands now, for the pane beside the grid; null when
/// there is none. Read by id, so a booking an address names is shown whatever
/// period the grid is on.
final deskBookingByIdProvider = FutureProvider.autoDispose
    .family<Reservation?, String>(
      (ref, id) => ref.watch(reservationRepositoryProvider).fetchById(id),
    );
