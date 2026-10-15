// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — what the realtime invalidator needs from the app, as providers
// the composition root overrides (`realtimeWiringFromApp`,
// lib/app/realtime_invalidations.dart). Unwired, nothing is invalidated:
// there is no workspace and no map.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'invalidation_map.dart';

/// Which providers cache a table.
final invalidationLookupProvider =
    Provider<TableInvalidation Function(String table)>(
  (ref) => (table) => TableInvalidation([]),
);

/// The active workspace's id (null: none); the channel follows it.
final realtimeWorkspaceIdProvider = FutureProvider<String?>((ref) => null);

/// Clears the floor plan's disk cache.
final planCacheBusterProvider =
    Provider<Future<void> Function()>((ref) => () async {});
