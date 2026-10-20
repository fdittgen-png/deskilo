// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — what the realtime invalidator needs from the app, as providers
// the composition root overrides (`realtimeWiringFromApp`,
// lib/app/realtime_invalidations.dart). Unwired, nothing is invalidated:
// there is no workspace and no map.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../backend/context_client_providers.dart';
import 'invalidation_map.dart';
import 'invalidation_registry.dart';

/// Which providers cache a table, per target scope.
final invalidationLookupProvider = Provider<InvalidationLookup>(
  (ref) => (table, {scopes}) => TableInvalidation([]),
);

/// #2564 O5 — the client of the selected workspace's installation: its
/// change feed is the workspace target's. Overridden by the app with
/// `selectedWorkspaceClientProvider`; the default is the personal home's.
final realtimeWorkspaceClientProvider = Provider<SupabaseClient>(
  (ref) => ref.watch(personalClientProvider),
);

/// The active workspace's id (null: none); the channel follows it.
final realtimeWorkspaceIdProvider = FutureProvider<String?>((ref) => null);

/// Clears the floor plan's disk cache.
final planCacheBusterProvider =
    Provider<Future<void> Function()>((ref) => () async {});
