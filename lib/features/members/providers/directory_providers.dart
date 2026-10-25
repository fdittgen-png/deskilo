// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/settings/directory_windows.dart';
import '../../../core/time/clock.dart';
import '../../reservations/domain/reservation.dart';
import '../../reservations/providers/reservation_providers.dart';

part 'directory_providers.g.dart';

/// All reservations feeding the directory's reservation chips (#237):
/// the month windows covering now through
/// `now + [DirectoryReservationRules.upcomingWindow]`, merged and
/// deduplicated by id (a booking spanning a month boundary appears in
/// both windows). Reuses [reservationsForMonthProvider] so the directory
/// shares the calendar's cache; the resolver
/// (`resolveReservationInfo`) trims this to what a chip actually shows.
@riverpod
Future<List<Reservation>> directoryReservations(Ref ref) async {
  final now = ref.read(clockProvider).now();
  final horizon = now.add(ref.watch(directoryWindowsProvider).upcomingWindow);
  // Set literal: both keys collapse to one when the window stays inside
  // a single month.
  final monthKeys = {monthKeyOf(now), monthKeyOf(horizon)};
  // #1218 — the watches are materialised BEFORE the await rather than
  // handed to `Future.wait` as a lazy map. They were already safe (the
  // iterable is walked eagerly), but "safe because of when Future.wait
  // happens to iterate" is not a thing the next reader should have to
  // know, and it is what a scanner cannot tell from a real gap.
  final futures = [
    for (final key in monthKeys)
      ref.watch(reservationsForMonthProvider(key).future),
  ];
  final windows = await Future.wait(futures);
  final seen = <String>{};
  return [
    for (final window in windows)
      for (final r in window)
        if (seen.add(r.id)) r,
  ];
}
