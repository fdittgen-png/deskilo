// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — what the floor plan caches, by table. Composed in
// lib/app/realtime_invalidations.dart.
import '../../../core/realtime/invalidation_registry.dart';
import 'floor_plan_providers.dart';

final planInvalidations = [
  // #1084 — these ARE the plan. Both providers read `cacheFirst` off a
  // 10-minute disk entry, so invalidating the provider without busting the
  // cache refetches straight back into the stale bundle.
  InvalidationContribution(
    const ['levels', 'offices', 'desks', 'seats', 'plan_images'],
    [levelsProvider, floorPlanProvider],
    bustsPlanCache: true,
  ),
  // Seat accessory data rides the floor plan fetch, and its cache.
  InvalidationContribution(
    const ['accessories', 'seat_accessories'],
    [floorPlanProvider],
    bustsPlanCache: true,
  ),
  // #572 — a members change can be this user's approval, which widens what
  // RLS lets them read; everything fetched under the old horizon is stale.
  InvalidationContribution(
    const ['members'],
    [levelsProvider, floorPlanProvider, targetNamesProvider],
    bustsPlanCache: true,
  ),
  InvalidationContribution(const ['reservations'], [targetNamesProvider]),
];
