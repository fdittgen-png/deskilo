// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — what the events feature caches, by table. Composed in
// lib/app/realtime_invalidations.dart.
import '../../../core/realtime/invalidation_registry.dart';
import 'event_providers.dart';

final eventsInvalidations = [
  InvalidationContribution(
    const ['events'],
    [eventsProvider, eventDecisionsProvider, myPendingEventCountProvider],
  ),
  // #3099 (PERF-2) — a decision changes the decisions, not the feed: the
  // 100-row events page (and the sweep before it) stays cached, and the
  // decisions derived from it are read again.
  InvalidationContribution(
    const ['event_decisions'],
    [eventDecisionsProvider, myPendingEventCountProvider],
  ),
  InvalidationContribution(
    const ['validation_policies'],
    [validationPoliciesProvider],
  ),
];
