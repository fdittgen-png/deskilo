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

/// Reservations of the active workspace intersecting the given UTC day
/// (keyed by 'yyyy-MM-dd' to keep family keys canonical).
@riverpod
Future<List<Reservation>> reservationsForDay(Ref ref, String dayKey) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  final parts = dayKey.split('-').map(int.parse).toList();
  final from = DateTime.utc(parts[0], parts[1], parts[2]);
  final to = from.add(const Duration(days: 1));
  return ref
      .watch(reservationRepositoryProvider)
      .fetchWindow(workspace.id, from: from, to: to);
}

/// member id → display name for the active workspace.
@Riverpod(keepAlive: true)
Future<Map<String, String>> memberNames(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  return ref.watch(workspaceRepositoryProvider).fetchMemberNames(workspace.id);
}

/// Canonical family key for [reservationsForDay].
String dayKeyOf(DateTime at) {
  final utc = at.toUtc();
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$m-$d';
}
