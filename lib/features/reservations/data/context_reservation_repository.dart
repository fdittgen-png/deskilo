// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 C1 -- the first reservation read that runs on an operation context.
// `fetchWindow` takes the workspace context once, at the start of the call,
// and reads through THAT context's verified host client and a cache view of
// that target alone. Everything else on the repository is unchanged and
// migrates with #2564.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/operation_context.dart';
import '../../../core/cache/cache_store.dart';
import '../../../core/cache/target_cache_store.dart';
import '../domain/reservation.dart';
import 'supabase_reservation_repository.dart';

/// The context captured for an operation no longer matches the workspace the
/// caller asked about (it switched meanwhile): nothing is read.
class StaleWorkspaceContext implements Exception {
  const StaleWorkspaceContext(this.asked, this.current);
  final String asked;
  final String current;
  @override
  String toString() => 'StaleWorkspaceContext: asked $asked, context is $current';
}

class ContextReservationRepository extends SupabaseReservationRepository {
  ContextReservationRepository(
    super.client,
    super.cache, {
    required this.context,
    required this.clientFor,
  }) : _base = cache;

  /// The operation context at the moment of the call.
  final Future<WorkspaceContext?> Function() context;

  /// The client of a verified installation.
  final SupabaseClient Function(String installationId) clientFor;
  final CacheStore _base;

  @override
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final captured = await context();
    if (captured == null) return const [];
    if (captured.target.workspaceId != workspaceId) {
      throw StaleWorkspaceContext(workspaceId, captured.target.workspaceId);
    }
    return SupabaseReservationRepository(
      clientFor(captured.target.installationId),
      TargetCacheStore(_base, captured.cacheNamespace),
    ).fetchWindow(workspaceId, from: from, to: to);
  }
}
