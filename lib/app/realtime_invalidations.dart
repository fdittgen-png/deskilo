// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — THE table -> cached-providers registry (#577), composed where the
// features are. Each feature declares the providers of its own that cache a
// table (`<feature>/providers/realtime_invalidations.dart`); core/realtime
// knows the tables, the contribution shape and how a batch is applied. Both
// freshness paths (realtime events and a screen's own mutation) read this
// one registry through core's `invalidationLookupProvider`, so it cannot
// drift against itself. Anything not listed still refetches on the next
// natural invalidation; a new cached provider is declared by its feature.
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/realtime/invalidation_map.dart';
import '../core/realtime/invalidation_registry.dart';
import '../core/realtime/realtime_wiring.dart';
import '../features/calendar/providers/realtime_invalidations.dart';
import '../features/events/providers/realtime_invalidations.dart';
import '../features/members/providers/realtime_invalidations.dart';
import '../features/money/providers/realtime_invalidations.dart';
import '../features/plan/providers/floor_plan_providers.dart';
import '../features/plan/providers/realtime_invalidations.dart';
import '../features/reservations/providers/realtime_invalidations.dart';
import '../features/workspace/providers/realtime_invalidations.dart';
import '../features/workspace/providers/workspace_providers.dart';

/// Puts the registry, the plan-cache bust and the active workspace in a
/// scope's overrides (main.dart, the demo container, the test helper).
final List<Override> realtimeWiringFromApp = [
  invalidationLookupProvider.overrideWithValue(invalidationFor),
  realtimeWorkspaceIdProvider.overrideWith(
    (ref) async => (await ref.watch(currentWorkspaceProvider.future))?.id,
  ),
  planCacheBusterProvider.overrideWith(
    (ref) => ref.read(floorPlanRepositoryProvider).invalidateCache,
  ),
];

/// Every feature's declarations, composed. The one registry of the app.
@visibleForTesting
final InvalidationRegistry realtimeInvalidationRegistry = InvalidationRegistry([
  ...calendarInvalidations,
  ...eventsInvalidations,
  ...membersInvalidations,
  ...moneyInvalidations,
  ...planInvalidations,
  ...reservationsInvalidations,
  ...workspaceInvalidations,
]);

/// What [table] invalidates on the single active-workspace channel, which
/// today applies every scope; a target-narrowed lookup is
/// [InvalidationRegistry.lookup] with `scopes`.
@visibleForTesting
TableInvalidation invalidationFor(String table) =>
    realtimeInvalidationRegistry.lookup(table);
