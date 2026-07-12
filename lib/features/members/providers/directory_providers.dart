// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../profile/domain/profile.dart';
import '../../profile/providers/profile_providers.dart';
import '../../reservations/domain/reservation.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/directory_status.dart';

part 'directory_providers.g.dart';

/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. RLS already trims the read to people
/// sharing a workspace with the caller (#223).
@riverpod
Future<Map<String, Profile>> memberProfiles(Ref ref) async {
  final members = await ref.watch(workspaceMembersProvider.future);
  if (members.isEmpty) return const {};
  final profiles = await ref
      .watch(profileRepositoryProvider)
      .fetchProfiles(members.map((m) => m.userId).toList());
  return {for (final p in profiles) p.id: p};
}

/// All reservations feeding the directory's reservation chips (#237):
/// the month windows covering now through
/// `now + [DirectoryReservationRules.upcomingWindow]`, merged and
/// deduplicated by id (a booking spanning a month boundary appears in
/// both windows). Reuses [reservationsForMonthProvider] so the directory
/// shares the calendar's cache; the resolver
/// (`resolveReservationInfo`) trims this to what a chip actually shows.
@riverpod
Future<List<Reservation>> directoryReservations(Ref ref) async {
  final now = DateTime.now();
  final horizon = now.add(DirectoryReservationRules.upcomingWindow);
  // Set literal: both keys collapse to one when the window stays inside
  // a single month.
  final monthKeys = {monthKeyOf(now), monthKeyOf(horizon)};
  final windows = await Future.wait(
    monthKeys.map((key) => ref.watch(reservationsForMonthProvider(key).future)),
  );
  final seen = <String>{};
  return [
    for (final window in windows)
      for (final r in window)
        if (seen.add(r.id)) r,
  ];
}
