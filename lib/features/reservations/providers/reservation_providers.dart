// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_reservation_repository.dart';
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';

part 'reservation_providers.g.dart';

@Riverpod(keepAlive: true)
ReservationRepository reservationRepository(Ref ref) =>
    SupabaseReservationRepository(Supabase.instance.client);

/// Reservations of the active workspace intersecting the given LOCAL day
/// (keyed 'yyyy-MM-dd'). Local, not UTC: the user thinks in wall-clock
/// days, and a UTC window shifts the visible day east/west of UTC (#119).
@riverpod
Future<List<Reservation>> reservationsForDay(Ref ref, String dayKey) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  final parts = dayKey.split('-').map(int.parse).toList();
  final from = DateTime(parts[0], parts[1], parts[2]);
  final to = DateTime(parts[0], parts[1], parts[2] + 1);
  return ref
      .watch(reservationRepositoryProvider)
      .fetchWindow(workspace.id, from: from, to: to);
}

/// My reserved (not yet checked-in) bookings starting within 7 days —
/// feeds the local check-in reminders (spec §4.3).
@riverpod
Future<List<Reservation>> myUpcomingReservations(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final member = await ref.watch(myMemberProvider.future);
  if (workspace == null || member == null) return const [];
  final now = DateTime.now();
  final window = await ref.watch(reservationRepositoryProvider).fetchWindow(
        workspace.id,
        from: now,
        to: now.add(const Duration(days: 7)),
      );
  return window
      .where((r) =>
          r.memberId == member.id &&
          r.status == ReservationStatus.reserved &&
          r.startsAt.isAfter(now))
      .toList();
}

/// member id → display name for the active workspace.
@Riverpod(keepAlive: true)
Future<Map<String, String>> memberNames(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  return ref.watch(workspaceRepositoryProvider).fetchMemberNames(workspace.id);
}

/// Reservations of the active workspace intersecting the given LOCAL
/// month (keyed 'yyyy-MM'). See [reservationsForDay] for why local (#119):
/// a UTC key turned the July calendar into a June query east of UTC.
@riverpod
Future<List<Reservation>> reservationsForMonth(Ref ref, String monthKey) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  final parts = monthKey.split('-').map(int.parse).toList();
  final from = DateTime(parts[0], parts[1]);
  final to = DateTime(parts[0], parts[1] + 1);
  return ref
      .watch(reservationRepositoryProvider)
      .fetchWindow(workspace.id, from: from, to: to);
}

/// Canonical family key for [reservationsForMonth] — LOCAL wall-clock
/// month of [at], never UTC (#119).
String monthKeyOf(DateTime at) {
  final local = at.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}';
}

/// Canonical family key for [reservationsForDay] — LOCAL wall-clock day.
String dayKeyOf(DateTime at) {
  final local = at.toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}
