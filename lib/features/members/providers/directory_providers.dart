// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../profile/domain/profile.dart';
import '../../profile/providers/profile_providers.dart';
import '../../reservations/domain/reservation.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/directory_status.dart';
import '../../../core/time/clock.dart';

part 'directory_providers.g.dart';

/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. RLS already trims the read to people
/// sharing a workspace with the caller (#223).
@riverpod
Future<Map<String, Profile>> memberProfiles(Ref ref) async {
  final members = await ref.watch(workspaceMembersProvider.future);
  // A managed member (#962) has no account and therefore no profile;
  // its empty user id must never reach the query, where PostgREST
  // rejects the whole request over one malformed uuid.
  final ids = accountIdsOf(members);
  if (ids.isEmpty) return const {};
  final profiles =
      await ref.watch(profileRepositoryProvider).fetchProfiles(ids);
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
  final now = ref.read(clockProvider).now();
  final horizon = now.add(DirectoryReservationRules.upcomingWindow);
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
